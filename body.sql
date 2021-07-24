-------------------------!-------------------!---------------------------------------------------
-------------------------!-------------------!---------------------------------------------------
-------------------------!---Package Body ---!---------------------------------------------------
-------------------------!-------------------!---------------------------------------------------
-------------------------!-------------------!---------------------------------------------------
CREATE
OR REPLACE PACKAGE BODY "AAA_CAP_MODEL_HEDAYAT" IS 

/* define procedures and functions*/

PROCEDURE update_model_stat_step_prc(
  p_num_step IN NUMBER,
  P_NUM_MODULE IN NUMBER,
  p_flg_stat IN NUMBER
  ) IS 
  lv_msg2 VARCHAR2(500);
  BEGIN
    IF (p_flg_stat = 0) THEN
      SELECT
        fp.val_att3_lmpfp INTO lv_msg2
      FROM
        lmp.lmp_bas_fix_params fp
      WHERE
        fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
        AND fp.val_att1_lmpfp = 2;

      UPDATE
        lmp_bas_model_run_stats S1
      SET
        S1.dat_start_mosta = SYSDATE,
        S1.sta_step_mosta = lv_msg2,
        S1.Cod_Run_Mjl_Mosta = AAA_CAP_MODEL_HEDAYAT.code_run_global_variable
      WHERE
      S1.cod_run_mosta = AAA_CAP_MODEL_HEDAYAT.code_run_tot_global_variable
      AND S1.num_step_mosta = p_num_step
      AND S1.NUM_MODULE_MOSTA = P_NUM_MODULE;
    ELSE ---update 
      IF p_flg_stat = 1 THEN ----successful
        SELECT
          fp.val_att3_lmpfp INTO lv_msg2
        FROM
          lmp.lmp_bas_fix_params fp
        WHERE
          fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
          AND fp.val_att1_lmpfp = 3;

        UPDATE
          lmp_bas_model_run_stats s1
        SET
          s1.dat_end_mosta = SYSDATE,
          s1.sta_step_mosta = lv_msg2
        WHERE
        s1.cod_run_mosta = AAA_CAP_MODEL_HEDAYAT.code_run_tot_global_variable
        AND (
          AAA_CAP_MODEL_HEDAYAT.code_run_global_variable IS NULL
          OR S1.Cod_Run_Mjl_Mosta = AAA_CAP_MODEL_HEDAYAT.code_run_global_variable
        )
        AND s1.num_step_mosta = p_num_step
        AND S1.NUM_MODULE_MOSTA = P_NUM_MODULE;

      ELSE ----error
        SELECT
          fp.val_att3_lmpfp INTO lv_msg2
        FROM
          lmp.lmp_bas_fix_params fp
        WHERE
          fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
          AND fp.val_att1_lmpfp = 4;

        UPDATE
          lmp_bas_model_run_stats s1
        SET
          s1.sta_step_mosta = lv_msg2
        WHERE
        s1.cod_run_mosta = AAA_CAP_MODEL_HEDAYAT.code_run_tot_global_variable
        AND (
          AAA_CAP_MODEL_HEDAYAT.code_run_global_variable IS NULL
          OR S1.Cod_Run_Mjl_Mosta = AAA_CAP_MODEL_HEDAYAT.code_run_global_variable
        )
        AND s1.num_step_mosta = p_num_step
        AND S1.NUM_MODULE_MOSTA = P_NUM_MODULE;

      END IF;
    END IF;
END;

PROCEDURE FILL_LMP_BAS_RUN_HISTORIES (
  p_date_start IN DATE,
  P_date_end IN DATE,
  p_description IN VARCHAR2
  ) IS
  /* declare local variables*/
  lv_last_plan_dat DATE;
  lv_MAS_RUN_ID NUMBER;

  BEGIN
    SELECT
      MAX(cc.Dat_Calde) INTO lv_last_plan_dat
    FROM
      aac_lmp_calendar_viw cc
    WHERE
      cc.v_Dat_Calde_In_6 = (
        SELECT
          C .v_Dat_Calde_In_6
        FROM
          aac_lmp_calendar_viw C
        WHERE
          C .Dat_Calde = trunc(p_date_start)
      );

    SELECT
      MAX(t.Msch_Run_History_Id) AS Msch_Run_History_Id INTO lv_MAS_RUN_ID
    FROM
      mas.Mas_Msch_Run_Histories t
    WHERE
      Nvl(t.Num_Module_Mrhis, 1) = 20
      AND t.lkp_sta_model_mrhis = 'SUCCESSFUL';

    INSERT INTO
      LMP_BAS_RUN_HISTORIES (
        BAS_RUN_HISTORY_ID,
        COD_RUN_RNHIS,
        DAT_RUN_RNHIS,
        NUM_MODULE_RNHIS,
        STA_RUN_RNHIS,
        DAT_STRT_HRZN_RNHIS,
        DAT_END_HRZN_RNHIS,
        VAL_RUN_RNHIS,
        DES_DESCRIPTION_RNHIS,
        LKP_GROUP_RNHIS,
        FLG_IN_RUN_RNHIS,
        DAT_LAST_PLAN_RNHIS,
        mrhis_msch_run_history_id
      )
    VALUES
      (
        LMP_BAS_RUN_HISTORIES_SEQ.NEXTVAL,
        code_run_global_variable,
        SYSDATE,
        3,
        0,
        p_date_START,
        p_date_END,
        TO_CHAR(SYSDATE, 'YYYYMMDD'),
        p_description,
        'LMP',
        1,
        lv_last_plan_dat,
        lv_MAS_RUN_ID
      );

    COMMIT;
END;

PROCEDURE run_model_manual_prc(
  p_flg_run_service IN NUMBER) IS
  /* declare local variables*/
  lv_connection_server VARCHAR2(30);
  lv_string VARCHAR2(1000);
  lv_num NUMBER := 1;
  lv_msg VARCHAR2(1000);

  BEGIN
    AAA_CAP_MODEL_HEDAYAT.FILL_LMP_BAS_RUN_HISTORIES (
      trunc(SYSDATE),
      trunc(SYSDATE + 29 + 30),
      'Scheduled ' || to_char(SYSDATE, 'YYYY-MM-DD hh:mi:ss')
    );

    AAA_CAP_MODEL_HEDAYAT.create_model_data_prc();

    /*
    -----
    DELETE FROM
    LMP.LMP_CAP_DBD_INPUTS t
    WHERE
    t.lkp_typ_dbdin = 'FIX_TON_DAY'
    AND cod_run_dbdin = lv_cod_run
    AND t.statn_bas_station_id IS NULL;
    
    --lv_cod_run:='CAP1397061401';
    COMMIT;
    
    --call webservice
    IF nvl(p_flg_run_service, 0) = 1 THEN BEGIN
    lv_msg := Fnd.Fnd_Sms_And_Email_Pkg.Send_Non_Adv_Sms_Fun(
    sys.odciVarchar2List('09131657097'),
    p_Messagebodies = > 'DONE' || ' : ' || to_char(SYSDATE, 'MM/DD HH24:MI')
    );
    
    EXCEPTION
    WHEN OTHERS THEN NULL;
    
    END;
    
    --Dbms_lock.sleep(60);
    SELECT
    NAME INTO lv_connection_server
    FROM
    v$database;
    
    lv_num := APP_LMP_CAP_TOT_MODEL_PKG.run_cap_model_fun(
    p_cod_run = > lv_cod_run,
    p_connection_server = > lv_connection_server,
    p_identifierName = > '1'
    );
    
    END IF;
    
    COMMIT;
    */
END;

FUNCTION get_bas_run_history_fun RETURN RECORD IS
  /* define local variables*/
  TYPE history_record_type IS RECORD(
    lv_dat_start DATE,
    lv_dat_end DATE,
    lv_module NUMBER
  );
  lv_history_record history_record_type;

  BEGIN
    SELECT
    t.dat_strt_hrzn_rnhis,
    t.dat_end_hrzn_rnhis,
    t.num_module_rnhis INTO lv_history_record.lv_dat_start,
    lv_history_record.lv_dat_end,
    lv_history_record.lv_module
    FROM
      lmp_bas_run_histories t
    WHERE
      t.cod_run_rnhis = APP_LMP_CAP_HEDAYAT_PKG.code_run_global_variable;

    RETURN lv_history_record;

END;

PROCEDURE create_model_data_prc IS
  /* define types*/
  TYPE history_record_type IS RECORD(
    lv_dat_start DATE,
    lv_dat_end DATE,
    lv_module NUMBER
  );
  /* define local variables*/
  lv_history_record history_record_type;
  lv_month_cur VARCHAR2(6);
  lv_month_next VARCHAR2(6);
  lv_num_day NUMBER;
  lv_rem_tot NUMBER;
  lv_num_minues_day NUMBER;
  lv_min_inv NUMBER;
  lv_first_inv NUMBER;
  lv_tot_cap NUMBER;
  lv_pdw_ccm NUMBER := 196;
  LV_COUNT NUMBER;
  LV_CAP_AVLBL_TOT NUMBER;
  LV_CAP_FURNACE NUMBER;
  LV_CAP_CASTING NUMBER;
  LV_FACTOR NUMBER;
  lv_plan_sch NUMBER;
  lv_plan NUMBER;
  lv_dat_start_smc DATE;
  lv_round_base NUMBER;
BEGIN
  --* get lv_dat_start, lv_dat_end, lv_module from lmp_bas_run_histories table. 
  lv_history_record := APP_LMP_CAP_HEDAYAT_PKG.get_bas_run_history_fun;

  APP_LMP_CAP_HEDAYAT_PKG.update_model_stat_step_prc(
    p_num_step = > 1,
    P_NUM_MODULE = > lv_history_record.lv_module,
    p_flg_stat = > 0
  );

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
    lv_history_record.lv_module
  );

UPDATE
  lmp.lmp_bas_run_histories rh
SET
  rh.des_status_rnhis = 'RUNNING STEP 1'
WHERE
  rh.cod_run_rnhis = APP_LMP_CAP_HEDAYAT_PKG.code_run_global_variable
  AND rh.num_module_rnhis =lv_history_record.lv_module;

COMMIT;

INSERT INTO
  lmp_sop_og_periods (
    sop_og_period_id,
    orgrp_sop_order_group_id,
    cod_run_ogprd,
    dat_day_ogprd,
    num_module_ogprd,
    qty_min_daily_ogprd,
    qty_max_daily_ogprd
  )
SELECT
  lmp_sop_og_assigns_seq.nextval,
  ogtt.sop_order_group_id,
  APP_LMP_CAP_HEDAYAT_PKG.code_run_global_variable,
  ogtt.dat_calde,
  lv_history_record.lv_module,
  CASE
    WHEN ogpt.qty_min_daily_ogprd IS NULL THEN ogtt.qty_min_daily_orgrp
    ELSE ogpt.qty_min_daily_ogprd
  END AS qty_min,
  CASE
    WHEN ogpt.qty_max_daily_ogprd IS NULL THEN ogtt.qty_max_daily_orgrp
    ELSE ogpt.qty_max_daily_ogprd
  END AS qty_max
FROM
  (
    SELECT
      og.sop_order_group_id,
      C .Dat_Calde,
      og.qty_min_daily_orgrp,
      og.qty_max_daily_orgrp
    FROM
      lmp_sop_order_groups og,
      aac_lmp_calendar_viw C,
      lmp_sop_order_group_types ogt
    WHERE
      ogt.sop_order_group_type_id = og.ogtyp_sop_order_group_type_id
      AND ogt.typ_group_type_ogtyp = 1
      AND C .Dat_Calde BETWEEN lv_dat_start
      AND lv_dat_end
  ) ogtt,
  (
    SELECT
      ogp.orgrp_sop_order_group_id,
      ogp.dat_day_ogprd,
      ogp.qty_min_daily_ogprd,
      ogp.qty_max_daily_ogprd
    FROM
      lmp_sop_og_periods ogp
    WHERE
      ogp.dat_day_ogprd BETWEEN lv_dat_start
      AND lv_dat_end
      AND ogp.cod_run_ogprd = '0'
      AND ogp.num_module_ogprd = 3
  ) ogpt
WHERE
  ogtt.sop_order_group_id = ogpt.orgrp_sop_order_group_id(+)
  AND ogtt.dat_calde = ogpt.dat_day_ogprd(+);
/*
INSERT INTO
  lmp_bas_camp_plans (
    bas_camp_plan_id,
    statn_bas_station_id,
    dat_day_cmppl,
    cmpdf_bas_camp_define_id,
    cod_run_cmppl,
    NUM_CAMP_CMPPL
  )
SELECT
  lmp_bas_capacity_plans_seq.nextval,
  p.statn_bas_station_id,
  p.dat_day_cmppl,
  p.cmpdf_bas_camp_define_id,
  APP_LMP_CAP_HEDAYAT_PKG.code_run_global_variable,
  p.num_camp_cmppl
FROM
  lmp.lmp_bas_camp_plans p
WHERE
  p.cod_run_cmppl = '0'
  AND p.dat_day_cmppl BETWEEN lv_dat_start
  AND lv_dat_end;

INSERT INTO
  lmp_bas_parameters (
    bas_parameter_id,
    cod_run_prmtr,
    nam_ful_far_prmtr,
    nam_ful_latin_prmtr,
    num_module_prmtr,
    typ_cap_prmtr,
    val_parameter_prmtr,
    lkp_group_prmtr
  )
SELECT
  lmp_bas_parameters_seq.nextval,
  APP_LMP_CAP_HEDAYAT_PKG.code_run_global_variable,
  p.nam_ful_far_prmtr,
  p.nam_ful_latin_prmtr,
  lv_history_record.lv_module,
  p.typ_cap_prmtr,
  p.val_parameter_prmtr,
  p.lkp_group_prmtr
FROM
  lmp_bas_parameters p
WHERE
  p.cod_run_prmtr = '0'
  AND p.num_module_prmtr = 3 
  AND p.lkp_group_prmtr = 'LMP';

INSERT INTO
  lmp_bas_orders (
    bas_order_id,
    cod_order_lmpor,
    cod_run_lmpor,
    flg_db_order_lmpor,
    num_order_lmpor,
    profm_bas_product_family_id,
    qty_demand_lmpor,
    cod_smc_cycle_lmpor,
    cod_hsm_cycle_lmpor,
    cod_crm_cycle_lmpor,
    typ_box_cycle_lmpor,
    val_price_lmpor,
    dat_dlv_lmpor,
    cod_order_group_lmpor,
    flg_from_hsm_lmpor,
    VAL_WEEK_LMPOR,
    NUM_WID_SLAB_LMPOR,
    NUM_WID_LMPOR,
    NUM_TKS_LMPOR,
    COD_INT_QUAL_LMPOR,
    QTY_SLAB_NEED_LMPOR,
    QTY_COIL_HSM_NEED_LMPOR,
    VAL_DATLAST_SMC_LMPOR,
    VAL_DATLAST_HSM_LMPOR,
    FLG_ACTIVE_IN_MODEL_LMPOR,
    QTY_HSM_INV_LMPOR,
    QTY_HFL_INV_LMPOR,
    QTY_SHP_INV_LMPOR,
    COD_ORD_MIS_LMPOR,
    COD_INTERNAL_ORD_LMPOR,
    COD_SUS_PRTO_LMPOR,
    FLG_VIRTUAL_LMPOR,
    NUM_PRIORITY_LMPOR,
    dat_agg_dlv_lmpor,
    dat_last_hsm_lmpor,
    QTY_FIRST_DEMAND_LMPOR,
    DAT_FIRST_DLV_LMPOR,
    FLG_FIRTS_ACTIVE_LMPOR
  )
SELECT
  lmp_bas_orders_seq.nextval,
  o.cod_order_lmpor,
  APP_LMP_CAP_HEDAYAT_PKG.code_run_global_variable,
  o.flg_db_order_lmpor,
  o.num_order_lmpor,
  o.profm_bas_product_family_id,
  o.qty_demand_lmpor,
  o.cod_smc_cycle_lmpor,
  o.cod_hsm_cycle_lmpor,
  o.cod_crm_cycle_lmpor,
  o.typ_box_cycle_lmpor,
  o.val_price_lmpor,
  o.dat_dlv_lmpor,
  o.cod_order_group_lmpor,
  o.flg_from_hsm_lmpor,
  o.val_week_lmpor,
  o.num_wid_slab_lmpor,
  o.num_wid_lmpor,
  o.num_tks_lmpor,
  o.cod_int_qual_lmpor,
  o.qty_slab_need_lmpor,
  o.qty_coil_hsm_need_lmpor,
  o.val_datlast_smc_lmpor,
  o.val_datlast_hsm_lmpor,
  o.flg_active_in_model_lmpor,
  o.qty_hsm_inv_lmpor,
  o.qty_hfl_inv_lmpor,
  o.qty_shp_inv_lmpor,
  o.cod_ord_mis_lmpor,
  o.cod_internal_ord_lmpor,
  o.cod_sus_prto_lmpor,
  o.FLG_VIRTUAL_LMPOR,
  o.num_priority_lmpor,
  o.dat_agg_dlv_lmpor,
  o.dat_last_hsm_lmpor,
  o.QTY_FIRST_DEMAND_LMPOR,
  o.DAT_FIRST_DLV_LMPOR,
  o.FLG_FIRTS_ACTIVE_LMPOR
FROM
  lmp_bas_orders o
WHERE
  o.cod_run_lmpor = '00' 
;

INSERT INTO
  lmp.lmp_bas_constraints (
    bas_constraint_id,
    cnstr_bas_constraint_id,
    statn_bas_station_id,
    cod_run_cnstr,
    dat_day_cnstr,
    num_module_cnstr,
    qty_max_day_cnstr,
    qty_min_day_cnstr,
    typ_constraint_cnstr,
    typ_stock_flow_cnstr,
    ptype_bas_product_type_id,
    profm_bas_product_family_id,
    cod_constraint_cnstr,
    flg_active_cnstr
  )
SELECT
  lmp.lmp_bas_constraints_seq.nextval,
  m.BAS_CONSTRAINT_ID AS master_id,
  m.statn_bas_station_id,
  APP_LMP_CAP_HEDAYAT_PKG.code_run_global_variable,
  m.dat_calde,
  lv_history_record.lv_module,
  nvl(d.qty_max_day_cnstr, m.qty_max_day_cnstr) AS qty_max,
  nvl(d.qty_min_day_cnstr, m.qty_min_day_cnstr) AS qty_min,
  m.typ_constraint_cnstr,
  m.typ_stock_flow_cnstr,
  m.ptype_bas_product_type_id,
  m.profm_bas_product_family_id,
  m.cod_constraint_cnstr,
  m.flg_active_cnstr
FROM
  (
    SELECT
      T.BAS_CONSTRAINT_ID,
      t.statn_bas_station_id,
      t.qty_max_day_cnstr,
      t.qty_min_day_cnstr,
      cal.v_dat_calde_in_8,
      cal.dat_calde,
      t.typ_constraint_cnstr,
      t.typ_stock_flow_cnstr,
      t.ptype_bas_product_type_id,
      t.profm_bas_product_family_id,
      t.cod_constraint_cnstr,
      t.flg_active_cnstr
    FROM
      LMP.LMP_BAS_CONSTRAINTS T,
      (
        SELECT
          C .V_DAT_CALDE_IN_8,
          C .DAT_CALDE
        FROM
          apps.lmp_aac_calendar_viw C
        WHERE
          C .DAT_CALDE BETWEEN lv_dat_start
          AND lv_dat_end
      ) cal
    WHERE
      T.FLG_ACTIVE_CAP_CNSTR = 1
      AND T.NUM_MODULE_CNSTR IS NULL
  ) m,
  (
    SELECT
      C .BAS_CONSTRAINT_ID,
      C .CNSTR_BAS_CONSTRAINT_ID,
      C .Dat_Day_Cnstr,
      C .QTY_MAX_day_CNSTR,
      C .QTY_MIN_day_CNSTR
    FROM
      lmp.LMP_BAS_CONSTRAINTS C,
      lmp.LMP_BAS_CONSTRAINTS C1
    WHERE
      C .CNSTR_BAS_CONSTRAINT_ID IS NOT NULL
      AND C .COD_RUN_CNSTR = '0'
      AND C .NUM_MODULE_CNSTR = 3
      AND C1.BAS_CONSTRAINT_ID = C .CNSTR_BAS_CONSTRAINT_ID
  ) d
WHERE
  m.BAS_CONSTRAINT_ID = d.cnstr_bas_constraint_id(+)
  AND m.dat_calde = d.dat_day_cnstr(+)
  AND (
    m.qty_max_day_cnstr > 0
    OR m.qty_min_day_cnstr > 0
  );

APP_LMP_CAP_TOT_MODEL_PKG.cal_aas_data_viw_prc (APP_LMP_CAP_HEDAYAT_PKG.code_run_global_variable );


APP_LMP_CAP_TOT_MODEL_PKG.calculate_capacity_prc(APP_LMP_CAP_HEDAYAT_PKG.code_run_global_variable );

COMMIT;

app_lmp_cap_tot_model_pkg.cal_target_month_prc(APP_LMP_CAP_HEDAYAT_PKG.code_run_global_variable );

INSERT INTO
  lmp.lmp_bas_fix_params (
    bas_fix_param_id,
    val_att1_lmpfp,
    val_att4_lmpfp,
    val_att2_lmpfp,
    dat_att_lmpfp,
    val_att3_lmpfp,
    lkp_typ_lmpfp
  )
SELECT
  lmp.lmp_bas_fix_params_seq.nextval,
  station_id,
  cod_ord_group,
  max_ton,
  Dat_Calde,
  p_cod_run,
  'MAX_TON_DAY'
FROM
  (
    SELECT
      t.val_att1_lmpfp AS station_id,
      t.val_att4_lmpfp AS cod_ord_group,
      t.val_att2_lmpfp AS max_ton
    FROM
      lmp.lmp_bas_fix_params t
    WHERE
      t.lkp_typ_lmpfp = 'DAY_BY_DAY'
      AND t.val_att1_lmpfp IN (41, 45, 68, 67, 65, 66, 77, 78, 79)
  ),
  (
    SELECT
      C .Dat_Calde
    FROM
      aac_lmp_calendar_viw C
    WHERE
      C .Dat_Calde BETWEEN lv_dat_start
      AND lv_dat_end
  );

UPDATE
  lmp.lmp_bas_fix_params t
SET
  t.val_att2_lmpfp = t.val_att2_lmpfp * 3
WHERE
  t.lkp_typ_lmpfp = 'MAX_TON_DAY'
  AND t.dat_att_lmpfp > lv_dat_end - 10
  AND t.val_att3_lmpfp = p_cod_run;

app_lmp_cap_reports_pkg.set_fix_ton_user_prc;

COMMIT;

INSERT INTO
  lmp.lmp_cap_dbd_inputs (
    CAP_DBD_INPUT_ID,
    DAT_DAY_DBDIN,
    STATN_BAS_STATION_ID,
    COD_ORDER_GROUP_DBDIN,
    QTY_MIN_DBDIN,
    QTY_PLAN_DBDIN,
    QTY_MAX_DBDIN,
    COD_RUN_DBDIN,
    LKP_TYP_DBDIN
  )
SELECT
  lmp.lmp_cap_dbd_inputs_seq.nextval,
  CAP_DBD.DAT_DAY_DBDIN AS date_day,
  CAP_DBD.STATN_BAS_STATION_ID AS station_Id,
  CAP_DBD.COD_ORDER_GROUP_DBDIN AS cod_order_group,
  CAP_DBD.QTY_MIN_DBDIN AS qty_min,
  CAP_DBD.QTY_PLAN_DBDIN AS qty_plan,
  CAP_DBD.QTY_MAX_DBDIN AS qty_max,
  p_cod_run,
  CAP_DBD.LKP_TYP_DBDIN AS lkp_typ
FROM
  LMP.LMP_CAP_DBD_INPUTS CAP_DBD
WHERE
  CAP_DBD.LKP_TYP_DBDIN = 'FIX_TON_DAY'
  AND CAP_DBD.COD_RUN_DBDIN = '0'
  AND cap_dbd.dat_day_dbdin BETWEEN lv_dat_start
  AND lv_dat_end;

lv_month_cur := to_char(SYSDATE, 'YYYYMM');

SELECT
  MIN(C .v_Dat_Calde_In_6) INTO lv_month_next
FROM
  aac_lmp_calendar_viw C
WHERE
  C .v_Dat_Calde_In_6 > lv_month_cur;

FOR i IN (
  SELECT
    ts.qty_plan_lstst,
    ts.qty_max_lstst,
    ts.qty_min_lstst,
    ts.statn_bas_station_id,
    pa.area_id,
    pa.arstu_ide_pk_arstu
  FROM
    lmp.lmp_sop_target_stations ts,
    lmp.lmp_bas_stations st,
    pms.pms_areas pa
  WHERE
    ts.cod_run_cap_lstst = '0'
    AND pa.area_id = st.area_area_id
    AND st.bas_station_id = ts.statn_bas_station_id
    AND ts.lkp_type_lstst = 'CAP_TARGET_STATION'
    AND ts.val_month_lstst = lv_month_next
    AND (
      ts.qty_plan_lstst > 0
      OR ts.qty_max_lstst > 0
      OR ts.qty_min_lstst > 0
    )
)
LOOP
 
INSERT INTO
  LMP.LMP_CAP_DBD_INPUTS (
    CAP_DBD_INPUT_ID,
    STATN_BAS_STATION_ID,
    VAL_MONTH_DBDIN,
    LKP_TYP_DBDIN,
    QTY_PLAN_DBDIN,
    COD_RUN_DBDIN,
    QTY_MAX_DBDIN,
    QTY_MIN_DBDIN
  )
VALUES
  (
    lmp.lmp_cap_dbd_inputs_seq.nextval,
    i.statn_bas_station_id,
    lv_month_next,
    'TOTAL_STATION',
    (
      i.qty_plan_lstst
      
    ) * (
      (
        SELECT
          COUNT(C .Dat_Calde)
        FROM
          aac_lmp_calendar_viw C
        WHERE
          C .v_Dat_Calde_In_6 = lv_month_next
          AND C .Dat_Calde <= lv_dat_end
      ) / (
        SELECT
          COUNT(C .Dat_Calde)
        FROM
          aac_lmp_calendar_viw C
        WHERE
          C .v_Dat_Calde_In_6 = lv_month_next
      )
    ),
    p_cod_run,
    (
      i.qty_max_lstst
     
    ) * (
      (
        SELECT
          COUNT(C .Dat_Calde)
        FROM
          aac_lmp_calendar_viw C
        WHERE
          C .v_Dat_Calde_In_6 = lv_month_next
          AND C .Dat_Calde <= lv_dat_end
      ) / (
        SELECT
          COUNT(C .Dat_Calde)
        FROM
          aac_lmp_calendar_viw C
        WHERE
          C .v_Dat_Calde_In_6 = lv_month_next
      )
    ),
    (
      i.qty_min_lstst
     
    ) * (
      (
        SELECT
          COUNT(C .Dat_Calde)
        FROM
          aac_lmp_calendar_viw C
        WHERE
          C .v_Dat_Calde_In_6 = lv_month_next
          AND C .Dat_Calde <= lv_dat_end
      ) / (
        SELECT
          COUNT(C .Dat_Calde)
        FROM
          aac_lmp_calendar_viw C
        WHERE
          C .v_Dat_Calde_In_6 = lv_month_next
      )
    )
  );

END
LOOP
;

FOR i IN (
  SELECT
    cdi.statn_bas_station_id,
    cdi.qty_plan_lstst,
    cdi.cod_order_group_lstst,
    cdi.Qty_Max_Lstst,
    cdi.Qty_Min_Lstst,
    pa.area_id,
    pa.arstu_ide_pk_arstu
  FROM
    LMP.Lmp_Sop_Target_Stations cdi,
    lmp.lmp_bas_stations st,
    pms.pms_areas pa
  WHERE
    cdi.lkp_type_lstst = 'CAP_TARGET_OG'
    AND cdi.val_month_lstst = lv_month_next
    AND pa.area_id = st.area_area_id
    AND st.bas_station_id = cdi.statn_bas_station_id
    AND cdi.cod_run_cap_lstst = '0'
)
LOOP
 
INSERT INTO
  LMP.LMP_CAP_DBD_INPUTS (
    CAP_DBD_INPUT_ID,
    STATN_BAS_STATION_ID,
    VAL_MONTH_DBDIN,
    LKP_TYP_DBDIN,
    QTY_PLAN_DBDIN,
    COD_RUN_DBDIN,
    QTY_MIN_DBDIN,
    QTY_Max_DBDIN,
    COD_ORDER_GROUP_DBDIN
  )
VALUES
  (
    lmp.lmp_cap_dbd_inputs_seq.nextval,
    i.statn_bas_station_id,
    lv_month_next,
    'TOTAL_STATION_OG',
    i.qty_plan_lstst * (
      (
        SELECT
          COUNT(C .Dat_Calde)
        FROM
          aac_lmp_calendar_viw C
        WHERE
          C .v_Dat_Calde_In_6 = lv_month_next
          AND C .Dat_Calde <= lv_dat_end
      ) / (
        SELECT
          COUNT(C .Dat_Calde)
        FROM
          aac_lmp_calendar_viw C
        WHERE
          C .v_Dat_Calde_In_6 = lv_month_next
      )
    ),
    APP_LMP_CAP_HEDAYAT_PKG.code_run_global_variable,
    i.qty_min_lstst,
    i.qty_max_lstst,
    i.cod_order_group_lstst
  );

END
LOOP
;

FOR i IN (
  SELECT
    t.statn_bas_station_id,
    t.val_month_dbdin,
    t.qty_plan_dbdin,
    t.qty_max_dbdin,
    t.qty_min_dbdin
  FROM
    lmp.lmp_cap_dbd_inputs t
  WHERE
    t.lkp_typ_dbdin = 'TOTAL_STATION'
    AND t.cod_run_dbdin = APP_LMP_CAP_HEDAYAT_PKG.code_run_global_variable
    AND t.statn_bas_station_id IN (41)
    AND (
      t.qty_plan_dbdin > 0
      OR t.qty_max_dbdin > 0
      OR t.qty_min_dbdin > 0
    )
)
LOOP
  lv_dat_start_smc := apps.api_mas_lmp_pkg.get_max_dat_prog_smc_Fun(apps.api_mas_models_pkg.Get_Last_AAS_Cod_Run_Fun);

SELECT
  COUNT(1) INTO LV_COUNT
FROM
  APPS.LMP_AAC_CALENDAR_VIW V
WHERE
  V.V_DAT_CALDE_IN_6 = I.VAL_MONTH_DBDIN
  AND V.DAT_CALDE > lv_dat_start_smc;

SELECT
  GREATEST(
    (8 * 24 * LV_COUNT) - nvl(
      SUM(
        nvl(fp.val_att7_lmpfp, 0) + nvl(fp.val_att8_lmpfp, 0)
      ),
      0
    ),
    0
  ) INTO LV_CAP_FURNACE
FROM
  lmp.lmp_bas_fix_params fp
WHERE
  fp.lkp_typ_lmpfp = 'FURNACE_STOP'
  AND TO_CHAR(
    fp.dat_att_lmpfp,
    'YYYYMM',
    'NLS_CALENDAR=PERSIAN'
  ) = I.VAL_MONTH_DBDIN
  AND TRUNC(fp.dat_att_lmpfp) > lv_dat_start_smc;

SELECT
  SUM(NVL(bc.qty_capacity_bacap, 0)) INTO LV_CAP_CASTING
FROM
  lmp.lmp_bas_capacities bc
WHERE
  bc.statn_bas_station_id = I.STATN_BAS_STATION_ID
  AND bc.cod_run_bacap = APP_LMP_CAP_HEDAYAT_PKG.code_run_global_variable
  AND bc.dat_day_bacap IN (
    SELECT
      c1.Dat_Calde
    FROM
      APPS.LMP_aac_calendar_viw c1
    WHERE
      c1.v_Dat_Calde_In_6 = I.VAL_MONTH_DBDIN
      AND c1.DAT_CALDE > lv_dat_start_smc
  );

LV_CAP_AVLBL_TOT := (5 * LV_CAP_CASTING) + LV_CAP_FURNACE;

FOR D IN (
  SELECT
    V.DAT_CALDE
  FROM
    APPS.LMP_AAC_CALENDAR_VIW V
  WHERE
    V.V_DAT_CALDE_IN_6 = I.VAL_MONTH_DBDIN
    AND V.DAT_CALDE > lv_dat_start_smc
  ORDER BY
    1
)
LOOP
SELECT
  (8 * 24) - (
    SELECT
      (
        nvl(
          SUM(
            nvl(fp.val_att7_lmpfp, 0) + nvl(fp.val_att8_lmpfp, 0)
          ),
          0
        )
      )
    FROM
      lmp.lmp_bas_fix_params fp
    WHERE
      fp.lkp_typ_lmpfp = 'FURNACE_STOP'
      AND trunc(fp.dat_att_lmpfp) = trunc(v.DAT_CALDE)
  ) INTO LV_CAP_FURNACE
FROM
  apps.lmp_aac_calendar_viw v
WHERE
  trunc(v.DAT_CALDE) = TRUNC(D.DAT_CALDE);

SELECT
  SUM(NVL(bc.qty_capacity_bacap, 0)) INTO LV_CAP_CASTING
FROM
  lmp.lmp_bas_capacities bc
WHERE
  bc.statn_bas_station_id = I.STATN_BAS_STATION_ID
  AND bc.cod_run_bacap = APP_LMP_CAP_HEDAYAT_PKG.code_run_global_variable
  AND TRUNC(bc.dat_day_bacap) = TRUNC(D.DAT_CALDE);

LV_FACTOR := ((5 * LV_CAP_CASTING) + LV_CAP_FURNACE) / LV_CAP_AVLBL_TOT;

INSERT INTO
  lmp.lmp_cap_dbd_inputs (
    cap_dbd_input_id,
    statn_bas_station_id,
    dat_day_dbdin,
    qty_plan_dbdin,
    qty_max_dbdin,
    lkp_typ_dbdin,
    cod_run_dbdin
  )
VALUES
  (
    lmp.lmp_cap_dbd_inputs_seq.nextval,
    I.STATN_BAS_STATION_ID,
    D.DAT_CALDE,
    ROUND(
      (
        ROUND(((i.qty_plan_dbdin * LV_FACTOR) / 50), 0) * 50
      ),
      0
    ),
    ROUND(
      (
        ROUND(((i.qty_plan_dbdin * LV_FACTOR) / 50), 0) * 50
      ) * 1.05,
      0
    ),
    'TOTAL_STATION_DAY',
    APP_LMP_CAP_HEDAYAT_PKG.code_run_global_variable
  );

END
LOOP
;

END
LOOP
;

FOR i IN (
  SELECT
    t.statn_bas_station_id,
    t.val_month_dbdin,
    t.qty_plan_dbdin,
    t.qty_max_dbdin,
    t.qty_min_dbdin
  FROM
    lmp.lmp_cap_dbd_inputs t
  WHERE
    t.lkp_typ_dbdin = 'TOTAL_STATION'
    AND t.cod_run_dbdin = APP_LMP_CAP_HEDAYAT_PKG.code_run_global_variable
    AND t.statn_bas_station_id IN (45) 
    AND (
      t.qty_plan_dbdin > 0
      OR t.qty_max_dbdin > 0
      OR t.qty_min_dbdin > 0
    )
)
LOOP
SELECT
  SUM(bc.qty_capacity_bacap) INTO lv_tot_cap
FROM
  lmp.lmp_bas_capacities bc
WHERE
  bc.statn_bas_station_id = i.statn_bas_station_id
  AND bc.cod_run_bacap = APP_LMP_CAP_HEDAYAT_PKG.code_run_global_variable
  AND bc.dat_day_bacap IN (
    SELECT
      c1.Dat_Calde
    FROM
      aac_lmp_calendar_viw c1
    WHERE
      c1.v_Dat_Calde_In_6 = i.val_month_dbdin
  );

IF lv_tot_cap <= 0 THEN CONTINUE;

END IF;

lv_round_base := 1;

INSERT INTO
  lmp.lmp_cap_dbd_inputs (
    cap_dbd_input_id,
    statn_bas_station_id,
    dat_day_dbdin,
    qty_plan_dbdin,
    qty_max_dbdin,
    lkp_typ_dbdin,
    cod_run_dbdin
  )
SELECT
  lmp.lmp_cap_dbd_inputs_seq.nextval,
  bc1.statn_bas_station_id,
  bc1.dat_day_bacap,
  round(
    (
      (bc1.qty_capacity_bacap / lv_tot_cap) * i.qty_plan_dbdin
    ) / lv_round_base
  ) * lv_round_base,
  round(
    (
      (bc1.qty_capacity_bacap / lv_tot_cap) * i.qty_max_dbdin * 1.05
    ) / lv_round_base
  ) * lv_round_base,
  'TOTAL_STATION_DAY',
  APP_LMP_CAP_HEDAYAT_PKG.code_run_global_variable
FROM
  lmp.lmp_bas_capacities bc1
WHERE
  bc1.statn_bas_station_id = i.statn_bas_station_id
  AND bc1.cod_run_bacap = APP_LMP_CAP_HEDAYAT_PKG.code_run_global_variable
  AND bc1.dat_day_bacap IN (
    SELECT
      c1.Dat_Calde
    FROM
      aac_lmp_calendar_viw c1
    WHERE
      c1.v_Dat_Calde_In_6 = i.val_month_dbdin
  );

END
LOOP
;

FOR i IN (
  SELECT
    t.statn_bas_station_id,
    t.val_month_dbdin,
    t.qty_plan_dbdin,
    t.qty_max_dbdin,
    t.qty_min_dbdin
  FROM
    lmp.lmp_cap_dbd_inputs t
  WHERE
    t.lkp_typ_dbdin = 'TOTAL_STATION'
    AND t.cod_run_dbdin = APP_LMP_CAP_HEDAYAT_PKG.code_run_global_variable
    AND t.statn_bas_station_id IN (
      SELECT
        st.bas_station_id
      FROM
        lmp.lmp_bas_stations st,
        pms.pms_areas pa
      WHERE
        pa.area_id = st.area_area_id
        AND (
          pa.arstu_ide_pk_arstu LIKE 'M.S.C CO/M.S.C/CCM%'
        )
    )
    AND (
      t.qty_plan_dbdin > 0
      OR t.qty_max_dbdin > 0
      OR t.qty_min_dbdin > 0
    )
)
LOOP
SELECT
  SUM(bc.qty_capacity_bacap) INTO lv_tot_cap
FROM
  lmp.lmp_bas_capacities bc
WHERE
  bc.statn_bas_station_id = i.statn_bas_station_id
  AND bc.cod_run_bacap = APP_LMP_CAP_HEDAYAT_PKG.code_run_global_variable
  AND bc.dat_day_bacap IN (
    SELECT
      c1.Dat_Calde
    FROM
      aac_lmp_calendar_viw c1
    WHERE
      c1.v_Dat_Calde_In_6 = i.val_month_dbdin
  );

IF lv_tot_cap <= 0 THEN CONTINUE;

END IF;

SELECT
  nvl(st.qty_prod_cost_statn, 100) INTO lv_round_base
FROM
  lmp.lmp_bas_stations st
WHERE
  st.bas_station_id = i.statn_bas_station_id;

lv_round_base := 1;

INSERT INTO
  lmp.lmp_cap_dbd_inputs (
    cap_dbd_input_id,
    statn_bas_station_id,
    dat_day_dbdin,
    qty_plan_dbdin,
    qty_max_dbdin,
    lkp_typ_dbdin,
    cod_run_dbdin
  )
SELECT
  lmp.lmp_cap_dbd_inputs_seq.nextval,
  bc1.statn_bas_station_id,
  bc1.dat_day_bacap,
  round(
    (
      (bc1.qty_capacity_bacap / lv_tot_cap) * i.qty_plan_dbdin
    ) / lv_round_base
  ) * lv_round_base,
  round(
    (
      (bc1.qty_capacity_bacap / lv_tot_cap) * i.qty_max_dbdin * 1.05
    ) / lv_round_base
  ) * lv_round_base,
  'TOTAL_STATION_DAY',
  APP_LMP_CAP_HEDAYAT_PKG.code_run_global_variable
FROM
  lmp.lmp_bas_capacities bc1
WHERE
  bc1.statn_bas_station_id = i.statn_bas_station_id
  AND bc1.cod_run_bacap = APP_LMP_CAP_HEDAYAT_PKG.code_run_global_variable
  AND bc1.dat_day_bacap IN (
    SELECT
      c1.Dat_Calde
    FROM
      aac_lmp_calendar_viw c1
    WHERE
      c1.v_Dat_Calde_In_6 = i.val_month_dbdin
  );

END
LOOP
;

UPDATE
  lmp_bas_model_run_stats m
SET
  m.dat_end_mosta = SYSDATE,
  m.sta_step_mosta = 'پايان موفق'
WHERE
  m.cod_run_mosta = APP_LMP_CAP_HEDAYAT_PKG.code_run_global_variable
  AND m.num_step_mosta = 1
  AND m.num_module_mosta = lv_history_record.lv_module;

AAA_CAP_MODEL_HEDAYAT.update_model_stat_step_prc(
  p_num_step = > 1,
  P_NUM_MODULE = > lv_history_record.lv_module,
  p_flg_stat = > 1
);

COMMIT;

END;
*/

-------------------------!--------------------!--------------------------------------------------
-------------------------!INITIALIZATION LOGIC!--------------------------------------------------
-------------------------!--------------------!--------------------------------------------------
  BEGIN
    -- * calculate code run
    SELECT
      COUNT(1) INTO code_run_global_variable
    FROM
      lmp_bas_run_histories t
    WHERE
      t.COD_RUN_RNHIS LIKE ('CAP' || to_char(SYSDATE, 'YYYYMMDD') || '%');

    code_run_global_variable := 'CAP' || (
      TO_CHAR(SYSDATE, 'YYYYMMDD') * 100 + (code_run_global_variable + 1)
    );

    -- * calculate code run total
    SELECT
      MAX(H.COD_RUN_RNHIS) INTO code_run_tot_global_variable
    FROM
      LMP.LMP_BAS_RUN_HISTORIES H
    WHERE
      H.NUM_MODULE_RNHIS = 0
      AND trunc(h.create_date) >= trunc(SYSDATE);

END "AAA_CAP_MODEL_HEDAYAT";