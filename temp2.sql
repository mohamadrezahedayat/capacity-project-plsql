function calc_dat_start_fun (
  p_month in VARCHAR2) return Date 
  is
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