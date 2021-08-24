-------------------------!-------------------!---------------------------------------------------
-------------------------!-------------------!---------------------------------------------------
-------------------------!---Package Body ---!---------------------------------------------------
-------------------------!-------------------!---------------------------------------------------
-------------------------!-------------------!---------------------------------------------------
CREATE
OR REPLACE PACKAGE BODY "AAA_CAP_MODEL_HEDAYAT" IS 
  
  type date_calde_cursor_type is ref cursor return aac_lmp_calendar_viw.Dat_Calde%type;
  
  PROCEDURE fill_released_sch_prc
    IS 
      lv_released NUMBER;
    BEGIN
      FOR o IN (
        SELECT
          fp.val_att4_lmpfp AS cod_og
        FROM
          lmp.lmp_bas_fix_params fp
        WHERE
          fp.lkp_typ_lmpfp = 'DAY_BY_DAY'
          AND fp.val_att1_lmpfp = 45
      )
      LOOP
        SELECT
          nvl(SUM(RV.SUM_WEI), 0) INTO lv_released
        FROM
          apps.hmp_lmp_release_sch_ord_viw RV
        WHERE
          lmp_ret_ord_group_for_ord_fun(RV.ORDER_CODE) = o.cod_og;

        INSERT INTO
          lmp.lmp_bas_fix_params (
            bas_fix_param_id,
            val_att3_lmpfp,
            lkp_typ_lmpfp,
            val_att2_lmpfp,
            val_att4_lmpfp
          )
        VALUES
          (
            lmp.lmp_bas_fix_params_seq.nextval,
            code_run_global_variable,
            'LAST_PLAN_OG',
            lv_released,
            o.cod_og
          );
      END LOOP;

  end;

  PROCEDURE ins_last_release_plan_to_param
    IS
    begin
    --Insert Last Released Plan Data into fixparam
      INSERT INTO
        lmp.lmp_bas_fix_params (
          bas_fix_param_id,
          val_att2_lmpfp,
          val_att3_lmpfp,
          dat_att_lmpfp,
          lkp_typ_lmpfp
        )
      VALUES
        (
          lmp.lmp_bas_fix_params_seq.nextval,
          45,
          code_run_global_variable,
          apps.api_mas_run_simulators_pkg.return_hsm_available_time_fun,
          'LAST_PLAN'
        );

      INSERT INTO
        lmp.lmp_bas_fix_params (
          bas_fix_param_id,
          val_att2_lmpfp,
          val_att3_lmpfp,
          dat_att_lmpfp,
          lkp_typ_lmpfp
        )
      VALUES
      (
        lmp.lmp_bas_fix_params_seq.nextval,
        45,
        code_run_global_variable,
        app_hmp_hsm_optimizer_pkg.Calc_Time_Release_Fun,
        'LAST_PLAN_TEST'
      );
  END;

  PROCEDURE fill_actual_data_prc
    is
    lv_act_month NUMBER;
    lv_dat_end_act DATE;
    lv_current_month VARCHAR2(6);
    begin
      
      BEGIN
        DELETE FROM
          lmp.lmp_bas_actual_datas A
        WHERE
          A.cod_run_lmpad = code_run_global_variable
          AND A.dat_day_lmpad = trunc(SYSDATE);

      EXCEPTION
        WHEN OTHERS THEN NULL;
      END;

    lv_dat_end_act := TRUNC(SYSDATE);
    lv_current_month := to_char(SYSDATE, 'YYYYMM', 'nls_calendar=persian');

    ---set data hsm
    App_Pms_For_Mas_Pkg.set_param_for_mas_viw_prc(
      lv_dat_end_act - 1,
      lv_dat_end_act + 1,
      NULL,
      1
    );

    FOR j IN (
      SELECT
        T.VAL_ATT1_LMPFP AS PF_ID,
        T.VAL_ATT4_LMPFP AS COD_PF,
        T.VAL_ATT3_LMPFP AS COD_OG
      FROM
        LMP.LMP_BAS_FIX_PARAMS T
      WHERE
        T.LKP_TYP_LMPFP LIKE 'SOP_OG_PF'
    )
    LOOP
      lv_act_month := 0;

      BEGIN
        SELECT
          nvl(SUM(t1.wei_actl_prdst), 0) INTO lv_act_month
        FROM
          apps.hsm_lmp_coil_51_produce_viw t1
        WHERE
          trunc(t1.DAT_REF_PRO_PRDST) >= lv_dat_end_act
          AND trunc(t1.DAT_REF_PRO_PRDST) < lv_dat_end_act + 1
          AND t1.COD_ORD_GRP_PRDST = j.cod_og;

      EXCEPTION
        WHEN no_data_found THEN lv_act_month := 0;
      END;

      IF lv_act_month > 0 THEN
        INSERT INTO
          lmp.lmp_bas_actual_datas (
            bas_actual_data_id,
            cod_run_lmpad,
            cod_station_lmpad,
            cod_prod_family_id_lmpad,
            cod_order_group_lmpad,
            val_month_lmpad,
            qty_actual_lmpad,
            dat_day_lmpad
          )
        VALUES
          (
            lmp.Lmp_Bas_Actual_Datas_seq.nextval,
            code_run_global_variable,
            45,
            j.pf_id,
            j.cod_og,
            lv_current_month,
            lv_act_month,
            lv_dat_end_act
          );

      END IF;

    END LOOP;
  end;

  PROCEDURE cal_aas_data_viw_prc
    IS 
      
    BEGIN
      -- fill Released Sch
      fill_released_sch_prc();

      --Insert Last Released Plan Data into fixparam
      ins_last_release_plan_to_param();

      ---- Fill Actuals---------------
      app_lmp_global_pkg.insert_log_prc(
        p_fun_nam => 'cal_actual_aas_prc',
        p_inputs => 'START',
        p_outputs => to_char(SYSDATE,'YYYYMMDD'),
        p_flg_ok => 1,
        p_des_error => NULL
      );

      fill_actual_data_prc();

      COMMIT;

      app_lmp_global_pkg.insert_log_prc(
        p_fun_nam => 'CAL_ACTUAL_PROD_PRC',
        p_inputs => 'END',
        p_outputs => to_char( SYSDATE,'YYYYMMDD'),
        p_flg_ok => 1,
        p_des_error => NULL
      );

  END;

  PROCEDURE fill_lmp_bas_constraints_prc(
    p_history_record in history_record_type
    ) IS 
    BEGIN
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
        code_run_global_variable,
        m.dat_calde,
        p_history_record.module,
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
                C .DAT_CALDE BETWEEN p_history_record.dat_start
                AND p_history_record.dat_end
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

  END;

  PROCEDURE fill_lmp_bas_orders_prc
    IS 
    BEGIN
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
        code_run_global_variable,
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
        o.cod_run_lmpor = '00';

  END;

  PROCEDURE  fill_lmp_bas_parameters_prc(
    p_module in number) is
    BEGIN
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
          code_run_global_variable,
          p.nam_ful_far_prmtr,
          p.nam_ful_latin_prmtr,
          p_module,
          p.typ_cap_prmtr,
          p.val_parameter_prmtr,
          p.lkp_group_prmtr
        FROM
          lmp_bas_parameters p
        WHERE
          p.cod_run_prmtr = '0'
          AND p.num_module_prmtr = 3 
          AND p.lkp_group_prmtr = 'LMP';
  END;

  PROCEDURE fill_lmp_bas_camp_plans_prc(
    p_date_start in DATE,
    p_date_end in DATE)IS
    BEGIN
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
        code_run_global_variable,
        p.num_camp_cmppl
      FROM
        lmp.lmp_bas_camp_plans p
      WHERE
        p.cod_run_cmppl = '0'
        AND p.dat_day_cmppl BETWEEN p_date_start
        AND p_date_end;
  END;

  PROCEDURE update_run_histories_prc(
    p_module IN number) IS
    BEGIN
      UPDATE
        lmp.lmp_bas_run_histories rh
      SET
        rh.des_status_rnhis = 'RUNNING STEP 1'
      WHERE
        rh.cod_run_rnhis = code_run_global_variable
        AND rh.num_module_rnhis =p_module;

      COMMIT;
  END;

  PROCEDURE fill_bas_model_run_stats_prc (
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
          code_run_global_variable,
          1,
          'آماده سازي داده با شماره اجراي جديد',
          'در حال اجرا',
          SYSDATE,
          p_module
        );

  END;

  PROCEDURE fill_sop_og_periods_prc (
      p_history_record IN history_record_type) IS 
    BEGIN
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
        code_run_global_variable,
        ogtt.dat_calde,
        p_history_record.module,
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
            AND C .Dat_Calde BETWEEN p_history_record.dat_start
            AND p_history_record.dat_end
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
            ogp.dat_day_ogprd BETWEEN p_history_record.dat_start
            AND p_history_record.dat_end
            AND ogp.cod_run_ogprd = '0'
            AND ogp.num_module_ogprd = 3
        ) ogpt
      WHERE
        ogtt.sop_order_group_id = ogpt.orgrp_sop_order_group_id(+)
        AND ogtt.dat_calde = ogpt.dat_day_ogprd(+);

  END;

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
          S1.Cod_Run_Mjl_Mosta = code_run_global_variable
        WHERE
        S1.cod_run_mosta = code_run_tot_global_variable
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
          s1.cod_run_mosta = code_run_tot_global_variable
          AND (
            code_run_global_variable IS NULL
            OR S1.Cod_Run_Mjl_Mosta = code_run_global_variable
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
          s1.cod_run_mosta = code_run_tot_global_variable
          AND (
            code_run_global_variable IS NULL
            OR S1.Cod_Run_Mjl_Mosta = code_run_global_variable
          )
          AND s1.num_step_mosta = p_num_step
          AND S1.NUM_MODULE_MOSTA = P_NUM_MODULE;

        END IF;
      END IF;
  END;

  PROCEDURE FILL_BAS_RUN_HISTORIES_PRC (
    p_date_start IN DATE,
    P_date_end IN DATE,
    p_description IN VARCHAR2
    ) IS
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
        MAX(t.Msch_Run_History_Id) AS Msch_Run_History_Id
      INTO
        lv_MAS_RUN_ID
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

  FUNCTION calculate_cap_heat_temp_fun(
    p_dat_calde   in date,
    p_num_furnace in lmp.lmp_bas_fix_params.val_att1_lmpfp%type,
    p_pdw         in lmp.lmp_bas_fix_params.val_att2_lmpfp%type,
    p_iu          in lmp.lmp_bas_fix_params.val_att7_lmpfp%type
    ) return number IS
    lv_stop number;
    
    begin
      SELECT
        nvl(SUM(nvl(fp.val_att7_lmpfp, 0) + nvl(fp.val_att8_lmpfp, 0)), 0) 
      INTO lv_stop
      FROM
        lmp.lmp_bas_fix_params fp
      WHERE
        fp.lkp_typ_lmpfp = 'FURNACE_STOP'
        AND fp.val_att1_lmpfp = p_num_furnace
        AND fp.dat_att_lmpfp = p_dat_calde;

      EXCEPTION
        WHEN no_data_found THEN lv_stop := 0;
      END;

      return (24 - lv_stop) * i.p_iu * i.p_pdw;
      
  end;

  PROCEDURE insert_cap_heat_temp_prc(
    p_cap_heat_temp in number,
    p_dat_calde     in date,
    p_num_furnace   in number) IS
    begin
      INSERT INTO
      lmp.lmp_cap_heat_plans (
        cap_heat_plan_id,
        dat_day_hetpl,
        cod_run_hetpl,
        num_furnace_hetpl,
        QTY_MAX_TON_HETPL,
        LKP_TYP_HETPL
      )
    VALUES
      (
        lmp.lmp_cap_heat_plans_seq.nextval,
        p_dat_calde,
        code_run_global_variable,
        p_num_furnace,
        p_cap_heat_temp,
        'تعداد'
      );
    
  end;

  PROCEDURE insert_cap_heat_prc(
    p_cap_heat      in number,
    p_dat_calde     in date) IS
    begin
      INSERT INTO
        lmp.lmp_bas_capacities (
          bas_capacity_id,
          statn_bas_station_id,
          dat_day_bacap,
          cod_run_bacap,
          qty_capacity_bacap
        )
      VALUES
        (
          lmp.lmp_bas_capacities_seq.nextval,
          NULL,
          p_dat_calde,
          code_run_global_variable,
          p_cap_heat
        ); 
    
  end;

  PROCEDURE calculate_cap_heat_prc(
    p_dat_calde in date) IS
    lv_cap_heat := 0;
    lv_cap_heat_temp NUMBER;
    begin

      -- for selected parameters calculate cap heat 
      FOR i IN (
        SELECT
          t.val_att1_lmpfp AS num_furnace,
          t.val_att2_lmpfp AS pdw,
          t.val_att7_lmpfp AS iu
        FROM
          lmp.lmp_bas_fix_params t
        WHERE
          t.lkp_typ_lmpfp = 'FURNACE_CAPACITY'
      )
      LOOP
        BEGIN
          -- calculate capacity heat  of each parameter in a specific date
          lv_cap_heat_temp := calculate_cap_heat_temp_fun(p_dat_calde, num_furnace, pdw, iu);

          -- insert capacity heat of each parameter in a specific date to lmp.lmp_cap_heat_plans 
          insert_cap_heat_temp_prc( cap_heat_temp , p_dat_calde, num_furnace);

          -- calculate capacity sum of heats in a specific date
          lv_cap_heat := lv_cap_heat + lv_cap_heat_temp;

      END LOOP;

      -- insert capacity total heat of all parameters  a specific date to lmp.lmp_bas_capacities
      insert_cap_heat_prc( lv_cap_heat, p_dat_calde);
  end;

  function calculate_lv_cap(
    p_calde_dat in date) return number is
    lv_cap number:=0;
    begin
      FOR t IN (
        SELECT
          t1.bas_station_id,
          nvl(t1.val_prod_modifier_statn, 0) AS val_prod_modifier_statn,
          nvl(t2.qty_maintenace_camai, 0) AS qty_maintenace_camai
        FROM
          (
            SELECT * FROM
              ( 
                SELECT
                  st.bas_station_id,
                  st.val_prod_modifier_statn
                FROM
                  lmp.lmp_bas_stations st,
                  pms_areas pa
                WHERE
                  st.area_area_id = pa.area_id
                  AND pa.arstu_ide_pk_arstu = 'M.S.C CO/M.S.C/SMC/CASTING AREA/CCM STATION/CCM'
              ),
              (
                 SELECT
                  C.Dat_Calde
                FROM
                  aac_lmp_calendar_viw C
                WHERE
                  C.Dat_Calde = p_calde_dat
              )
          ) t1,
          (
            SELECT
              m.statn_bas_station_id,
              m.dat_day_camai,
              nvl(m.qty_maintenace_camai, 0) + nvl(m.qty_inactive_camai, 0) + nvl(m.qty_service_camai, 0) + nvl(m.qty_crane_camai, 0) AS qty_maintenace_camai
            FROM
              lmp.lmp_cap_maintenances m
            WHERE
              m.dat_day_camai = p_calde_dat
          ) t2
        WHERE
          t1.dat_calde = t2.dat_day_camai(+)
          AND t1.bas_station_id = t2.statn_bas_station_id(+)
      )
      LOOP
        lv_cap := lv_cap + (
          (24 - t.qty_maintenace_camai) * t.val_prod_modifier_statn
        );

      END LOOP;
      return lv_cap;
  end;

  PROCEDURE insert_lv_cap_prc(
    p_lv_cap in number,
    p_dat_calde in date,
    )is
    lv_cap           NUMBER := 0;
    lv_pcn_nc_slab   NUMBER := 0;
    lv_pcn_du_slab   NUMBER := 0;
    lv_dat_start_smc date := apps.api_mas_lmp_pkg.get_max_dat_prog_smc_Fun(apps.api_mas_models_pkg.Get_Last_AAS_Cod_Run_Fun);
    begin
      lv_cap :=calculate_lv_cap(d.dat_calde);

      IF p_dat_calde > lv_dat_start_smc THEN
        INSERT INTO
          lmp.lmp_bas_capacities (
            bas_capacity_id,
            statn_bas_station_id,
            dat_day_bacap,
            qty_capacity_bacap,
            cod_run_bacap
          )
        VALUES
          (
            lmp.lmp_bas_capacities_seq.nextval,
            41,
            p_dat_calde,
            round(
              lv_cap * ((100 - (lv_pcn_du_slab + lv_pcn_nc_slab)) / 100),
              3
            ),
            code_run_global_variable
          );

      END IF;
  end;

  procedure insert_lv_cap_temp_prc(
    p_dat_calde in date
    )is
    lv_cap_temp number;
    begin
      FOR t IN (
        SELECT
          t1.bas_station_id,
          t1.arstu_ide_pk_arstu,
          t1.qty_prod_cap_statn,
          nvl(t1.val_prod_modifier_statn, 0) AS val_prod_modifier_statn,
          nvl(t2.qty_maintenace_camai, 0) AS qty_maintenace_camai
        FROM
          (
            SELECT *
            FROM
              (
                SELECT
                  st.bas_station_id,
                  st.val_prod_modifier_statn,
                  st.qty_prod_cap_statn,
                  pa.arstu_ide_pk_arstu
                FROM
                  lmp.lmp_bas_stations st,
                  pms_areas pa
                WHERE
                  st.area_area_id = pa.area_id
                  AND pa.arstu_ide_pk_arstu = 'M.S.C CO/M.S.C/SMC/SLAB-CONDITIONING/PULPIT-9'
              ),
              (
                SELECT
                  C.Dat_Calde
                FROM
                  aac_lmp_calendar_viw C
                WHERE
                  C.Dat_Calde = p_dat_calde
              )
          ) t1,
          (
            SELECT
              m.statn_bas_station_id,
              m.dat_day_camai,
              nvl(m.qty_maintenace_camai, 0) + nvl(m.qty_inactive_camai, 0) + nvl(m.qty_service_camai, 0) + nvl(m.qty_crane_camai, 0) AS qty_maintenace_camai,
              m.num_furnace_camai
            FROM
              lmp.lmp_cap_maintenances m
            WHERE
              m.dat_day_camai = p_dat_calde
          ) t2
        WHERE
          t1.dat_calde = t2.dat_day_camai(+)
          AND t1.bas_station_id = t2.statn_bas_station_id(+)
      )
      LOOP
        lv_cap_temp := calc_lv_cap_temp_fun( 
          p_dat_calde,
          t1.qty_prod_cap_statn,
          t1.val_prod_modifier_statn, 
          t2.qty_maintenace_camai );

        INSERT INTO
          lmp.lmp_bas_capacities (
            bas_capacity_id,
            statn_bas_station_id,
            dat_day_bacap,
            qty_capacity_bacap,
            cod_run_bacap
          )
        VALUES
          (
            lmp.lmp_bas_capacities_seq.nextval,
            t.bas_station_id,
            p_dat_calde,
            lv_cap_temp,
            code_run_global_variable
          );

      END LOOP;
  end;

  function calc_lv_cap_temp_fun(
    p_dat_calde                in date,
    p_qty_prod_cap_statn       in number,
    p_val_prod_modifier_statn  in number,
    p_qty_maintenace_camai     in number
    ) return number is
    lv_cap_temp number := 0;
    begin
      IF trunc(p_dat_calde) = trunc(SYSDATE) THEN lv_cap_temp := (
          greatest(
            p_qty_prod_cap_statn * ((18.5 - (SYSDATE - trunc(SYSDATE)) * 24) / 24),
            0
          ) * p_val_prod_modifier_statn
        );

      ELSE lv_cap_temp := (
          greatest(
            p_qty_prod_cap_statn * (1 - (p_qty_maintenace_camai / 24)),
            0
          ) * p_val_prod_modifier_statn
        );

      END IF;
    return lv_cap_temp;
  end;

  PROCEDURE insert_lv_cap_temp_hsm_prc(
    p_dat_calde in date
    )is
    lv_cap_temp       number;
    lv_3heat_coef     NUMBER := 0.95;
    lv_2heat_coef     NUMBER := 0.69;
    lv_pcn_du_slab    number := 0;
    lv_pcn_cap        NUMBER;
    lv_last_hsm_time  date:= apps.api_mas_run_simulators_pkg.return_hsm_available_time_fun;

    begin
      FOR t IN (
        SELECT
          t1.bas_station_id,
          t1.arstu_ide_pk_arstu,
          t1.qty_prod_cap_statn,
          nvl(t1.val_prod_modifier_statn, 0) AS val_prod_modifier_statn,
          nvl(t2.qty_maintenace_camai, 0) AS qty_maintenace_camai,
          t2.num_furnace_camai
        FROM
          (
            SELECT
              *
            FROM
              (
                SELECT
                  st.bas_station_id,
                  st.val_prod_modifier_statn,
                  st.qty_prod_cap_statn,
                  pa.arstu_ide_pk_arstu
                FROM
                  lmp.lmp_bas_stations st,
                  pms_areas pa
                WHERE
                  st.area_area_id = pa.area_id
                  AND pa.arstu_ide_pk_arstu LIKE 'M.S.C CO/M.S.C/HSM%'
              ),
              (
                SELECT
                  C.Dat_Calde
                FROM
                  aac_lmp_calendar_viw C
                WHERE
                  C.Dat_Calde = p_dat_calde
              )
          ) t1,
          (
            SELECT
              m.statn_bas_station_id,
              m.dat_day_camai,
              nvl(m.qty_maintenace_camai, 0) + nvl(m.qty_inactive_camai, 0) + nvl(m.qty_service_camai, 0) + nvl(m.qty_crane_camai, 0) AS qty_maintenace_camai,
              m.num_furnace_camai
            FROM
              lmp.lmp_cap_maintenances m
            WHERE
              m.dat_day_camai = p_dat_calde
          ) t2
        WHERE
          t1.dat_calde = t2.dat_day_camai(+)
          AND t1.bas_station_id = t2.statn_bas_station_id(+)
      )
      LOOP
        lv_cap_temp := (
          greatest(
            t.qty_prod_cap_statn - t.qty_maintenace_camai,
            0
          ) * t.val_prod_modifier_statn
        );  

        IF t.num_furnace_camai = 3 THEN lv_cap_temp := lv_cap_temp * lv_3heat_coef;
        END IF;

        IF t.num_furnace_camai = 2 THEN lv_cap_temp := lv_cap_temp * lv_2heat_coef;
        END IF;

        IF t.arstu_ide_pk_arstu = 'M.S.C CO/M.S.C/HSM/HSM1' THEN 
          IF ((trunc(p_dat_calde) + 18.5 / 24) <= lv_last_hsm_time) THEN lv_pcn_cap := 0;

          ELSIF (
            (trunc(p_dat_calde) + 18.5 / 24) > lv_last_hsm_time
            )
            AND(
              (trunc(p_dat_calde - 1) + 18.5 / 24) < lv_last_hsm_time
            ) THEN lv_pcn_cap :=(
              (trunc(p_dat_calde) + 18.5 / 24) - greatest(
                (trunc(p_dat_calde - 1) + 18.5 / 24),
                lv_last_hsm_time
              )
            );

          ELSE lv_pcn_cap := 1;

          END IF;

            INSERT INTO
              lmp.lmp_bas_capacities (
                bas_capacity_id,
                statn_bas_station_id,
                dat_day_bacap,
                qty_capacity_bacap,
                cod_run_bacap
              )
            VALUES
              (
                lmp.lmp_bas_capacities_seq.nextval,
                t.bas_station_id,
                p_dat_calde,
                greatest(
                  round(
                    lv_pcn_cap * lv_cap_temp * ((100 - lv_pcn_du_slab) / 100),
                    3
                  ),
                  0
                ),
                code_run_global_variable
              );

        ELSE
          INSERT INTO
            lmp.lmp_bas_capacities (
              bas_capacity_id,
              statn_bas_station_id,
              dat_day_bacap,
              qty_capacity_bacap,
              cod_run_bacap
            )
          VALUES
            (
              lmp.lmp_bas_capacities_seq.nextval,
              t.bas_station_id,
              p_dat_calde,
              lv_cap_temp,
              code_run_global_variable
            );

        END IF;

      END LOOP;
  end;

  PROCEDURE insert_lv_cap_temp_crm_prc(
    p_dat_calde in date
    )is
    lv_cap_temp number;

    begin
      FOR t IN (
        SELECT
          t1.bas_station_id,
          t1.arstu_ide_pk_arstu,
          t1.qty_prod_cap_statn,
          nvl(t1.val_prod_modifier_statn, 0) AS val_prod_modifier_statn,
          nvl(t2.qty_maintenace_camai, 0) AS qty_maintenace_camai,
          t2.num_furnace_camai
        FROM
          (
            SELECT * FROM
              (
                SELECT
                  st.bas_station_id,
                  st.val_prod_modifier_statn,
                  st.qty_prod_cap_statn,
                  pa.arstu_ide_pk_arstu
                FROM
                  lmp.lmp_bas_stations st,
                  pms_areas pa
                WHERE
                  st.area_area_id = pa.area_id
                  AND pa.arstu_ide_pk_arstu LIKE 'M.S.C CO/M.S.C/CCM%'
              ),
              (
                SELECT
                  C.Dat_Calde
                FROM
                  aac_lmp_calendar_viw C
                WHERE
                  C.Dat_Calde = p_dat_calde
              )
          ) t1,
          (
            SELECT
              m.statn_bas_station_id,
              m.dat_day_camai,
              nvl(m.qty_maintenace_camai, 0) + nvl(m.qty_inactive_camai, 0) + nvl(m.qty_service_camai, 0) + nvl(m.qty_crane_camai, 0) AS qty_maintenace_camai,
              m.num_furnace_camai
            FROM
              lmp.lmp_cap_maintenances m
            WHERE
              m.dat_day_camai = p_dat_calde
          ) t2
        WHERE
          t1.dat_calde = t2.dat_day_camai(+)
          AND t1.bas_station_id = t2.statn_bas_station_id(+)
      )
      LOOP
        lv_cap_temp := (
          greatest(
            t.qty_prod_cap_statn - t.qty_maintenace_camai,
            0
          ) * t.val_prod_modifier_statn
        );

        INSERT INTO
          lmp.lmp_bas_capacities (
            bas_capacity_id,
            statn_bas_station_id,
            dat_day_bacap,
            qty_capacity_bacap,
            cod_run_bacap
          )
        VALUES
          (
            lmp.lmp_bas_capacities_seq.nextval,
            t.bas_station_id,
            p_dat_calde,
            lv_cap_temp,
            code_run_global_variable
          );

      END LOOP;
      
  end;

  PROCEDURE insert_lv_cap_temp_2_prc(
    p_dat_calde in date
    )is
    lv_cap_temp number;

    begin
      FOR t IN (
        SELECT
          st.bas_station_id,
          st.qty_prod_cap_statn
        FROM
          lmp_bas_stations st
        WHERE
          st.bas_station_id = 46
      )
    LOOP
      lv_cap_temp := nvl(t.qty_prod_cap_statn, 0);

      INSERT INTO
        lmp.lmp_bas_capacities (
          bas_capacity_id,
          statn_bas_station_id,
          dat_day_bacap,
          qty_capacity_bacap,
          cod_run_bacap
        )
      VALUES
      (
        lmp.lmp_bas_capacities_seq.nextval,
        t.bas_station_id,
        p_dat_calde,
        lv_cap_temp,
        code_run_global_variable
      );

    END LOOP;
      
  end;

  PROCEDURE insert_cap_inventory_prc 
    is
    lv_avail_inv NUMBER;
    lv_min_inv_cap NUMBER;
    begin

      FOR s IN (
        SELECT
          st.bas_station_id,
          pa.area_id,
          nvl(st.qty_min_inv_statn, 0) qty_min_inv_statn
        FROM
          lmp.lmp_bas_stations st,
          pms_areas pa
        WHERE
          pa.area_id = st.area_area_id
          AND pa.arstu_ide_pk_arstu NOT LIKE 'M.S.C CO/M.S.C/CCM%'
      )
      LOOP
        lv_min_inv_cap := s.qty_min_inv_statn;

        SELECT
          round(SUM(im.mu_wei) / 1000) INTO lv_avail_inv
        FROM
          mas_lmp_initial_mu_viw im,
          lmp.lmp_bas_orders o
        WHERE
          im.station_id = s.bas_station_id
          AND o.cod_run_lmpor = code_run_global_variable
          AND o.flg_active_in_model_lmpor = 1
          AND o.cod_order_lmpor = im.cod_ord_ordhe
          AND o.num_order_lmpor = im.num_item_ordit;

          IF lv_avail_inv < lv_min_inv_cap THEN 
            FOR C IN (
              SELECT
                cal.Dat_Calde
              FROM
                aac_lmp_calendar_viw cal
              WHERE
                cal.Dat_Calde BETWEEN history_record_global.dat_start
                AND history_record_global.dat_end
              ORDER BY
                cal.Dat_Calde
            )
            LOOP
            -- ! ????
              lv_avail_inv := lv_avail_inv * 1.05;

              IF lv_avail_inv >= lv_min_inv_cap THEN EXIT;
              END IF;

              INSERT INTO
                lmp.lmp_cap_dbd_inputs (
                  cap_dbd_input_id,
                  statn_bas_station_id,
                  dat_day_dbdin,
                  lkp_typ_dbdin,
                  cod_run_dbdin,
                  qty_min_dbdin
                )
              VALUES
                (
                  lmp.lmp_cap_dbd_inputs_seq.nextval,
                  s.bas_station_id,
                  C.dat_calde,
                  'INVENTORY_CAPACITY',
                  code_run_global_variable,
                  round(lv_avail_inv)
                );

            END LOOP;

          END IF;

      END LOOP;
  end;

  PROCEDURE calculate_capacity_prc
    IS 
    BEGIN
      FOR j IN (
        SELECT
          C.Dat_Calde
        FROM
          aac_lmp_calendar_viw C
        WHERE
          C.Dat_Calde BETWEEN history_record_global.dat_start
          AND history_record_global.dat_end
      )
      LOOP
        -- calculate_cap_heat
        calculate_cap_heat_prc(j.dat_calde);

        --CCM
        insert_lv_cap_prc(j.dat_calde);

        --Send to HSM
        insert_lv_cap_temp_prc(j.dat_calde);

        --HSM
        insert_lv_cap_temp_hsm_prc(j.dat_calde);

        --CRM
        insert_lv_cap_temp_crm_prc(j.dat_calde);

        --SHP
        insert_lv_cap_temp_2_prc(j.dat_calde);
      END LOOP;

      --min_inventory
      insert_cap_inventory_prc();

  END;

  function calc_dat_start_fun (
    p_month in VARCHAR2) return Date is
    lv_start_dat   DATE;
    begin
      SELECT
            MIN(C.Dat_Calde)
          INTO
            lv_start_dat
          FROM
            aac_lmp_calendar_viw C
          WHERE
            C.v_Dat_Calde_In_6 = p_month;
      return lv_start_dat
  end;

  procedure fill_total_station_prc(
    p_month in VARCHAR2,
    p_start_dat in DATE
    )is
    lv_plan        NUMBER;
    lv_plan_sch    NUMBER;
    lv_max         NUMBER;
    lv_min         NUMBER;
    lv_act         NUMBER;
    begin
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
          AND ts.val_month_lstst = p_month
          AND (
            ts.qty_plan_lstst > 0
            OR ts.qty_max_lstst > 0
            OR ts.qty_min_lstst > 0
          )
      )
      LOOP
        --smc
        IF i.statn_bas_station_id = 41 THEN lv_plan := nvl(i.qty_plan_lstst, 0);

        lv_min := nvl(i.qty_min_lstst, 0);
        lv_max := nvl(i.qty_max_lstst, 0);

        SELECT
          nvl(round(SUM(wp.WEI_ACTL_PRODT) / 1000), 0) INTO lv_act
        FROM
          PMS_FOR_LMP_WEI_PROD_VIW wp
        WHERE
          wp.NAM_BRIEF LIKE 'CCM%'
          AND wp.DATE_GEN < history_record_global.dat_start;

        SELECT
          nvl(round(SUM(t1.WEI_ASSIGNED_KG) / 1000), 0) INTO lv_plan_sch
        FROM
          apps.mas_lmp_assigned_slab_typ_viw t1
        WHERE
          t1.NUM_AREA_ID_LOC_AASTH IN (161, 160, 162, 163, 7375133);

        INSERT INTO
          LMP.LMP_CAP_DBD_INPUTS (
            CAP_DBD_INPUT_ID,
            STATN_BAS_STATION_ID,
            VAL_MONTH_DBDIN,
            LKP_TYP_DBDIN,
            QTY_PLAN_DBDIN,
            QTY_MIN_DBDIN,
            QTY_MAX_DBDIN,
            COD_RUN_DBDIN
          )
        VALUES
          (
            lmp.lmp_cap_dbd_inputs_seq.nextval,
            i.statn_bas_station_id,
            p_month,
            'TOTAL_STATION',
            greatest(lv_plan - (nvl(lv_act, 0) + nvl(lv_plan_sch, 0)), 0 ),
            greatest(lv_min  - (nvl(lv_act, 0) + nvl(lv_plan_sch, 0)), 0 ),
            greatest(lv_max  - (nvl(lv_act, 0) + nvl(lv_plan_sch, 0)), 0 ),
            code_run_global_variable
          );

        END IF;

        --51
        IF i.statn_bas_station_id = 45 THEN lv_plan := nvl(i.qty_plan_lstst, 0);

        lv_min := nvl(i.qty_min_lstst, 0);

        lv_max := nvl(i.qty_max_lstst, 0);

        SELECT
          nvl(SUM(t.wei_actl_prdst) / 1000, 0) INTO lv_act
        FROM
          apps.hsm_lmp_coil_51_produce_viw t
        WHERE
          trunc(t.DAT_REF_PRO_PRDST) >= p_start_dat
          AND trunc(t.DAT_REF_PRO_PRDST) < history_record_global.dat_start;

        INSERT INTO
          LMP.LMP_CAP_DBD_INPUTS (
            CAP_DBD_INPUT_ID,
            STATN_BAS_STATION_ID,
            VAL_MONTH_DBDIN,
            LKP_TYP_DBDIN,
            QTY_PLAN_DBDIN,
            QTY_MIN_DBDIN,
            QTY_MAX_DBDIN,
            COD_RUN_DBDIN
          )
        VALUES
          (
            lmp.lmp_cap_dbd_inputs_seq.nextval,
            i.statn_bas_station_id,
            p_month,
            'TOTAL_STATION',
            greatest(
              lv_plan - lv_act - (
                SELECT
                  SUM(rv.SUM_WEI) / 1000
                FROM
                  apps.hmp_lmp_release_sch_ord_viw RV
              ),
              0
            ),
            greatest(lv_min - lv_act, 0),
            greatest(lv_max - lv_act, 0),
            code_run_global_variable
          );

        END IF;

        IF i.statn_bas_station_id = 3 THEN lv_plan := nvl(i.qty_plan_lstst, 0);

        lv_min := nvl(i.qty_min_lstst, 0);

        lv_max := nvl(i.qty_max_lstst, 0);

        SELECT
          nvl(SUM(t.wei_net_prdst) / 1000, 0) INTO lv_act
        FROM
          apps.ccm_lmp_accept_coil_viw t
        WHERE
          trunc(t.DAT_STK_PRDST) >= p_start_dat
          AND trunc(t.DAT_STK_PRDST) < history_record_global.dat_start;

        INSERT INTO
          LMP.LMP_CAP_DBD_INPUTS (
            CAP_DBD_INPUT_ID,
            STATN_BAS_STATION_ID,
            VAL_MONTH_DBDIN,
            LKP_TYP_DBDIN,
            QTY_PLAN_DBDIN,
            QTY_MIN_DBDIN,
            QTY_MAX_DBDIN,
            COD_RUN_DBDIN
          )
        VALUES
          (
            lmp.lmp_cap_dbd_inputs_seq.nextval,
            i.statn_bas_station_id,
            p_month,
            'TOTAL_STATION',
            greatest(lv_plan - lv_act, 0),
            greatest(lv_min - lv_act, 0),
            greatest(lv_max - lv_act, 0),
            code_run_global_variable
          );

        ELSE IF i.arstu_ide_pk_arstu LIKE 'M.S.C CO/M.S.C/CCM%' THEN lv_plan := nvl(i.qty_plan_lstst, 0);

        lv_min := nvl(i.qty_min_lstst, 0);

        lv_max := nvl(i.qty_max_lstst, 0);

        SELECT
          nvl(SUM(t.WEI) / 1000, 0) AS sum_ton INTO lv_act
        FROM
          CCM_FOR_MAS_PROD_VIW t
        WHERE
          t.AREA_ID = i.area_id
          AND t.DAT < history_record_global.dat_start;

        INSERT INTO
          LMP.LMP_CAP_DBD_INPUTS (
            CAP_DBD_INPUT_ID,
            STATN_BAS_STATION_ID,
            VAL_MONTH_DBDIN,
            LKP_TYP_DBDIN,
            QTY_PLAN_DBDIN,
            QTY_MIN_DBDIN,
            QTY_MAX_DBDIN,
            COD_RUN_DBDIN
          )
        VALUES
          (
            lmp.lmp_cap_dbd_inputs_seq.nextval,
            i.statn_bas_station_id,
            p_month,
            'TOTAL_STATION',
            greatest(lv_plan - lv_act, 0),
            greatest(lv_min - lv_act, 0),
            greatest(lv_max - lv_act, 0),
            code_run_global_variable
          );

        END IF;

        END IF;

      END LOOP;
    
  end;

  procedure fill_total_station_ccm_prc(
    p_month in VARCHAR2,
    )is
    lv_plan        NUMBER;
    lv_max         NUMBER;
    lv_min         NUMBER;
    lv_act         NUMBER;
    lv_targ        NUMBER;
    begin
      
      FOR i IN (
        SELECT
          st.bas_station_id,
          pa.area_id
        FROM
          lmp.lmp_bas_stations st,
          pms_areas pa
        WHERE
          pa.area_id = st.area_area_id
          AND pa.arstu_ide_pk_arstu LIKE 'M.S.C CO/M.S.C/CCM%'
      )
      LOOP

        FOR og IN (
          SELECT
            fp.val_att4_lmpfp AS cod_og
          FROM
            lmp.lmp_bas_fix_params fp
          WHERE
            fp.lkp_typ_lmpfp = 'DAY_BY_DAY'
            AND fp.val_att1_lmpfp = i.bas_station_id
        )
        LOOP
          SELECT
            SUM(dd.qty_prod_plan_dayby) INTO lv_plan
          FROM
            lmp.lmp_bas_day_by_days dd
          WHERE
            dd.statn_bas_station_id = i.bas_station_id
            AND dd.cod_ord_grp_dayby = og.cod_og
            AND to_char(dd.dat_day_dayby, 'YYYYMM') = p_month;

          BEGIN
            SELECT
              ts.qty_plan_lstst,
              ts.qty_max_lstst,
              ts.qty_min_lstst INTO lv_targ,
              lv_max,
              lv_min
            FROM
              lmp.lmp_sop_target_stations ts
            WHERE
              ts.cod_run_cap_lstst = '0'
              AND ts.lkp_type_lstst = 'CAP_TARGET_OG'
              AND ts.statn_bas_station_id = i.bas_station_id
              AND ts.val_month_lstst = p_month
              AND ts.cod_order_group_lstst = og.COD_OG;

          EXCEPTION
            WHEN OTHERS THEN lv_max := NULL;

          lv_min := NULL;

          lv_targ := NULL;

          END;

          lv_targ := nvl(lv_targ, lv_plan);

          SELECT
            (SUM(t.WEI) / 1000) INTO lv_act
          FROM
            CCM_FOR_MAS_PROD_VIW t
          WHERE
            t.DAT < history_record_global.dat_start
            AND t.AREA_ID = i.area_id
            AND lmp_ret_ord_group_for_ord_fun(
              p_cod_order = > t.ORDIT_ORDHE_COD_ORD_ORDHE || lpad(
                t.ORDIT_NUM_ITEM_ORDIT,
                3,
                '0'
              )
            ) = og.cod_og;

          INSERT INTO
            LMP.LMP_CAP_DBD_INPUTS (
              CAP_DBD_INPUT_ID,
              STATN_BAS_STATION_ID,
              VAL_MONTH_DBDIN,
              LKP_TYP_DBDIN,
              QTY_PLAN_DBDIN,
              COD_RUN_DBDIN,
              COD_ORDER_GROUP_DBDIN,
              QTY_max_DBDIN,
              QTY_min_DBDIN
            )
          VALUES
            (
              lmp.lmp_cap_dbd_inputs_seq.nextval,
              i.bas_station_id,
              p_month,
              'TOTAL_STATION_OG',
              greatest(lv_targ - nvl(lv_act, 0), 0),
              code_run_global_variable,
              og.cod_og,
              greatest(lv_max - nvl(lv_act, 0), 0),
              greatest(lv_min - nvl(lv_act, 0), 0)
            );

        END LOOP;

      END LOOP;
    
  end;

  procedure fill_total_station_og_prc(
    p_month in VARCHAR2,
    p_start_dat in DATE
    )is
    lv_plan        NUMBER;
    lv_max         NUMBER;
    lv_min         NUMBER;
    lv_act         NUMBER;
    lv_targ        NUMBER;
    lv_released    NUMBER;
    begin
      FOR og IN (
      SELECT
        fp.val_att4_lmpfp AS cod_og
      FROM
        lmp.lmp_bas_fix_params fp
      WHERE
        fp.lkp_typ_lmpfp = 'DAY_BY_DAY'
        AND fp.val_att1_lmpfp = 45
        AND fp.val_att4_lmpfp NOT IN ('01')
      )
      LOOP
        SELECT
          SUM(dd.qty_prod_plan_dayby) INTO lv_plan
        FROM
          lmp.lmp_bas_day_by_days dd
        WHERE
          dd.statn_bas_station_id = 45
          AND dd.cod_ord_grp_dayby = og.cod_og
          AND to_char(dd.dat_day_dayby, 'YYYYMM') = p_month;

        BEGIN
          SELECT
            ts.qty_plan_lstst,
            ts.qty_max_lstst,
            ts.qty_min_lstst INTO lv_targ,
            lv_max,
            lv_min
          FROM
            lmp.lmp_sop_target_stations ts
          WHERE
            ts.cod_run_cap_lstst = '0'
            AND ts.lkp_type_lstst = 'CAP_TARGET_OG'
            AND ts.statn_bas_station_id = 45
            AND ts.val_month_lstst = p_month
            AND ts.cod_order_group_lstst = og.COD_OG;

        EXCEPTION
          WHEN OTHERS THEN lv_max := NULL;

        lv_min := NULL;

        lv_targ := NULL;

        END;

        SELECT
          nvl(SUM(tt.wei_actl_prdst) / 1000, 0) INTO lv_act
        FROM
          apps.hsm_lmp_coil_51_produce_viw tt
        WHERE
          trunc(tt.DAT_REF_PRO_PRDST) >= p_start_dat
          AND trunc(tt.DAT_REF_PRO_PRDST) < history_record_global.dat_start
          AND tt.COD_ORD_GRP_PRDST = og.cod_og;

        lv_targ := nvl(lv_targ, lv_plan);

      
        --------------------Considering Released Plans in Targets --Hr.Ebrahimi 1399/09/02
        SELECT
          nvl(SUM(RV.SUM_WEI), 0) INTO lv_released
        FROM
          apps.hmp_lmp_release_sch_ord_viw RV
        WHERE
        
          lmp_ret_ord_group_for_ord_fun(RV.ORDER_CODE) = og.cod_og;

        INSERT INTO
          LMP.LMP_CAP_DBD_INPUTS (
            CAP_DBD_INPUT_ID,
            STATN_BAS_STATION_ID,
            VAL_MONTH_DBDIN,
            LKP_TYP_DBDIN,
            QTY_PLAN_DBDIN,
            COD_RUN_DBDIN,
            COD_ORDER_GROUP_DBDIN,
            QTY_max_DBDIN,
            QTY_min_DBDIN
          )
        VALUES
          (
            lmp.lmp_cap_dbd_inputs_seq.nextval,
            45,
            p_month,
            'TOTAL_STATION_OG',
            greatest(
              lv_targ - nvl(lv_act, 0) - nvl(lv_released / 1000, 0),
              0
            ),
            code_run_global_variable,
            og.cod_og,
            greatest(lv_max - nvl(lv_act, 0), 0),
            greatest(lv_min - nvl(lv_act, 0), 0)
          );

      END LOOP;
    
  end;

  procedure fill_total_station_casting_prc(
    p_month in VARCHAR2
    )is
    lv_max         NUMBER;
    lv_min         NUMBER;
    lv_act         NUMBER;
    lv_targ        NUMBER;
    begin
      FOR i IN (
        SELECT
          st.bas_station_id,
          pa.area_id
        FROM
          lmp.lmp_bas_stations st,
          pms_areas pa
        WHERE
          pa.area_id = st.area_area_id
          AND st.bas_station_id = 41
      )
      LOOP
        FOR og IN (
          SELECT
            fp.val_att4_lmpfp AS cod_og
          FROM
            lmp.lmp_bas_fix_params fp
          WHERE
            fp.lkp_typ_lmpfp = 'DAY_BY_DAY'
            AND fp.val_att1_lmpfp = i.bas_station_id
        )
        LOOP
          BEGIN
            SELECT
              ts.qty_plan_lstst,
              ts.qty_max_lstst,
              ts.qty_min_lstst INTO lv_targ,
              lv_max,
              lv_min
            FROM
              lmp.lmp_sop_target_stations ts
            WHERE
              ts.cod_run_cap_lstst = '0'
              AND ts.lkp_type_lstst = 'CAP_TARGET_OG'
              AND ts.statn_bas_station_id = i.bas_station_id
              AND ts.val_month_lstst = p_month
              AND ts.cod_order_group_lstst = og.COD_OG;

          EXCEPTION
            WHEN OTHERS THEN lv_max := NULL;

          lv_min := NULL;

          lv_targ := NULL;

          END;

          IF nvl(lv_max, 0) + nvl(lv_targ, 0) + nvl(lv_min, 0) = 0 THEN CONTINUE;

          END IF;

          SELECT
            round(SUM(tt.WEI_ACTL_PRDST) / 1000) INTO lv_act
          FROM
            apps.pms_for_smp_slab_prod_viw tt
          WHERE
            lmp_ret_ord_group_for_ord_fun(tt.numorder) = og.cod_og;

          INSERT INTO
            LMP.LMP_CAP_DBD_INPUTS (
              CAP_DBD_INPUT_ID,
              STATN_BAS_STATION_ID,
              VAL_MONTH_DBDIN,
              LKP_TYP_DBDIN,
              QTY_PLAN_DBDIN,
              COD_RUN_DBDIN,
              COD_ORDER_GROUP_DBDIN,
              QTY_max_DBDIN,
              QTY_min_DBDIN
            )
          VALUES
            (
              lmp.lmp_cap_dbd_inputs_seq.nextval,
              i.bas_station_id,
              p_month,
              'TOTAL_STATION_OG',
              greatest(lv_targ - (nvl(lv_act, 0)), 0),
              code_run_global_variable,
              og.cod_og,
              greatest(lv_max - (nvl(lv_act, 0)), 0),
              greatest(lv_min - (nvl(lv_act, 0)), 0)
            );

        END LOOP;

      END LOOP;
    
  end;

  PROCEDURE cal_target_month_prc
  IS
    lv_month       VARCHAR2(6);
    lv_start_dat   DATE;
    lv_plan        NUMBER;
    lv_max         NUMBER;
    lv_min         NUMBER;
    lv_act         NUMBER;
    lv_plan_sch    NUMBER;
    lv_num_seq     NUMBER;
    lv_targ        NUMBER;
    lv_released    NUMBER;
    BEGIN

      lv_month := to_char(history_record_global.dat_start, 'YYYYMM');
      lv_start_dat := calc_dat_start_fun (lv_month);
    
      lv_num_seq := app_lmp_params_pkg.update_str_date_smp_rep_fun( lv_start_dat);
      lv_num_seq := app_lmp_params_pkg.update_end_date_smp_rep_fun( trunc(SYSDATE));

      App_Pms_For_Mas_Pkg.set_param_for_mas_viw_prc(lv_start_dat, trunc(SYSDATE), NULL, 1);
      apps.APP_PMS_FOR_SMP_PKG.Set_Date_Prc(lv_start_dat, trunc(SYSDATE));

      fill_total_station_prc(lv_month, lv_start_dat);

      --محاسبه گروه سفارش براي خطوط سرد
      fill_total_station_ccm_prc( lv_month);

      --51 for og
      fill_total_station_og_prc(lv_month, lv_start_dat);
      
      --محاسبه گروه سفارش براي ريخته گري
      fill_total_station_casting_prc(lv_month);

  END;

  PROCEDURE create_model_data_prc
    IS
    lv_month_cur VARCHAR2(6);
    lv_month_next VARCHAR2(6);
    lv_tot_cap NUMBER;
    LV_COUNT NUMBER;
    LV_CAP_AVLBL_TOT NUMBER;
    LV_CAP_FURNACE NUMBER;
    LV_CAP_CASTING NUMBER;
    LV_FACTOR NUMBER;
    lv_dat_start_smc DATE;
    lv_round_base NUMBER;
    BEGIN
      
      -- parameters:  p_num_step , P_NUM_MODULE, p_flg_stat
      update_model_stat_step_prc(1, history_record_global.module,0);

      fill_bas_model_run_stats_prc(history_record_global.module);
      -- set---> des_status_rnhis = 'RUNNING STEP 1'
      update_run_histories_prc(history_record_global.module);

      fill_sop_og_periods_prc(history_record_global);

      fill_lmp_bas_camp_plans_prc(history_record_global.dat_start, history_record_global.dat_end);

      fill_lmp_bas_parameters_prc(history_record_global.module);

      fill_lmp_bas_orders_prc();

      fill_lmp_bas_constraints_prc(history_record_global);

      cal_aas_data_viw_prc ();

      calculate_capacity_prc();

      COMMIT;

      cal_target_month_prc();
  -- todo temp3 gooes here

  END;

PROCEDURE run_model_manual_prc(
  p_flg_run_service IN NUMBER) IS
  /* declare local variables*/ 
  lv_connection_server VARCHAR2(30);
  lv_string VARCHAR2(1000);
  lv_num NUMBER := 1;
  lv_msg VARCHAR2(1000);

  BEGIN
    FILL_BAS_RUN_HISTORIES_PRC (
      trunc(SYSDATE),
      trunc(SYSDATE + 29 + 30),
      'Scheduled ' || to_char(SYSDATE, 'YYYY-MM-DD hh:mi:ss')
    );

    create_model_data_prc();
-- todo conticnue this procedure
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
    p_Messagebodies => 'DONE' || ' : ' || to_char(SYSDATE, 'MM/DD HH24:MI')
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
    p_cod_run => lv_cod_run,
    p_connection_server => lv_connection_server,
    p_identifierName => '1'
    );
    
    END IF;
    
    COMMIT;
    */
END;

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

    --* get dat_start, dat_end, module from lmp_bas_run_histories table.
    SELECT
      t.dat_strt_hrzn_rnhis,
      t.dat_end_hrzn_rnhis,
      t.num_module_rnhis 
    INTO
      history_record_global.dat_start,
      history_record_global.dat_end,
      history_record_global.module
    FROM
      lmp_bas_run_histories t
    WHERE
      t.cod_run_rnhis = code_run_global_variable;

END "AAA_CAP_MODEL_HEDAYAT";