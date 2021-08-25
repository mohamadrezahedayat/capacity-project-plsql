PROCEDURE fill_bas_fix_params_prc is
  begin
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
    code_run_global_variable,
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
        C .Dat_Calde BETWEEN history_record_global.dat_start
        AND history_record_global.dat_end
    );
end;

PROCEDURE update_bas_fix_params_prc is
  begin
    UPDATE
      lmp.lmp_bas_fix_params t
    SET
      t.val_att2_lmpfp = t.val_att2_lmpfp * 3
    WHERE
      t.lkp_typ_lmpfp = 'MAX_TON_DAY'
      AND t.dat_att_lmpfp > history_record_global.dat_end - 10
      AND t.val_att3_lmpfp = code_run_global_variable;
end;

PROCEDURE fill_cap_dbd_inputs_fix_tonday_prc is
  begin
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
      code_run_global_variable,
      CAP_DBD.LKP_TYP_DBDIN AS lkp_typ
    FROM
      LMP.LMP_CAP_DBD_INPUTS CAP_DBD
    WHERE
      CAP_DBD.LKP_TYP_DBDIN = 'FIX_TON_DAY'
      AND CAP_DBD.COD_RUN_DBDIN = '0'
      AND cap_dbd.dat_day_dbdin BETWEEN history_record_global.dat_start
      AND history_record_global.dat_end;
end;

function calc_month_next_fun return varchar 
  is
  lv_month_next VARCHAR2(6);
  begin
    SELECT
      MIN(C .v_Dat_Calde_In_6) INTO lv_month_next
    FROM
      aac_lmp_calendar_viw C
    WHERE
      C .v_Dat_Calde_In_6 > to_char(SYSDATE, 'YYYYMM');

    retuen lv_month_next;
end;

procedure fill_CAP_DBD_INP_tot-st_prc(
  p_month_next in varchar2
  )is
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
        AND ts.val_month_lstst = p_month_next
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
          p_month_next,
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
                C .v_Dat_Calde_In_6 = p_month_next
                AND C .Dat_Calde <= history_record_global.dat_end
            ) / (
              SELECT
                COUNT(C .Dat_Calde)
              FROM
                aac_lmp_calendar_viw C
              WHERE
                C .v_Dat_Calde_In_6 = p_month_next
            )
          ),
          code_run_global_variable,
          (
            i.qty_max_lstst
          ) * (
            (
              SELECT
                COUNT(C .Dat_Calde)
              FROM
                aac_lmp_calendar_viw C
              WHERE
                C .v_Dat_Calde_In_6 = p_month_next
                AND C .Dat_Calde <= history_record_global.dat_end
            ) / (
              SELECT
                COUNT(C .Dat_Calde)
              FROM
                aac_lmp_calendar_viw C
              WHERE
                C .v_Dat_Calde_In_6 = p_month_next
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
                C .v_Dat_Calde_In_6 = p_month_next
                AND C .Dat_Calde <= history_record_global.dat_end
            ) / (
              SELECT
                COUNT(C .Dat_Calde)
              FROM
                aac_lmp_calendar_viw C
              WHERE
                C .v_Dat_Calde_In_6 = p_month_next
            )
          )
        );

    END LOOP;
end;

procedure fill_CAP_DBD_INP_tot-st_og_prc(
  p_month_next in varchar2
  )is
  begin
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
        AND cdi.val_month_lstst = p_month_next
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
          p_month_next,
          'TOTAL_STATION_OG',
          i.qty_plan_lstst * (
            (
              SELECT
                COUNT(C .Dat_Calde)
              FROM
                aac_lmp_calendar_viw C
              WHERE
                C .v_Dat_Calde_In_6 = p_month_next
                AND C .Dat_Calde <= history_record_global.dat_end
            ) / (
              SELECT
                COUNT(C .Dat_Calde)
              FROM
                aac_lmp_calendar_viw C
              WHERE
                C .v_Dat_Calde_In_6 = p_month_next
            )
          ),
          code_run_global_variable,
          i.qty_min_lstst,
          i.qty_max_lstst,
          i.cod_order_group_lstst
        );

    END LOOP;
end;

procedure fill_CAP_DBD_INP_tot_st_day_1_prc 
  is
  LV_COUNT NUMBER;
  LV_CAP_AVLBL_TOT NUMBER;
  LV_CAP_FURNACE NUMBER;
  LV_CAP_CASTING NUMBER;
  LV_FACTOR NUMBER;
  lv_dat_start_smc DATE;

  begin
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
        AND t.cod_run_dbdin = code_run_global_variable
        AND t.statn_bas_station_id IN (41)
        AND (
          t.qty_plan_dbdin > 0
          OR t.qty_max_dbdin > 0
          OR t.qty_min_dbdin > 0
        )
    )
    LOOP
    --! potential bug ...
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
        AND bc.cod_run_bacap = code_run_global_variable
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

      -- loop c-1
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
          AND bc.cod_run_bacap = code_run_global_variable
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
            code_run_global_variable
          );

      END LOOP;

    END LOOP;
END

procedure fill_CAP_DBD_INP_tot_st_day_2_prc 
  is
  lv_tot_cap NUMBER;
  lv_round_base NUMBER;
  begin
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
        AND t.cod_run_dbdin = code_run_global_variable
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
        AND bc.cod_run_bacap = code_run_global_variable
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
        code_run_global_variable
      FROM
        lmp.lmp_bas_capacities bc1
      WHERE
        bc1.statn_bas_station_id = i.statn_bas_station_id
        AND bc1.cod_run_bacap = code_run_global_variable
        AND bc1.dat_day_bacap IN (
          SELECT
            c1.Dat_Calde
          FROM
            aac_lmp_calendar_viw c1
          WHERE
            c1.v_Dat_Calde_In_6 = i.val_month_dbdin
        );

    END LOOP;
end;

procedure fill_CAP_DBD_INP_tot_st_day_3_prc 
  is
  lv_tot_cap NUMBER;
  lv_round_base NUMBER;
  begin
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
        AND t.cod_run_dbdin = code_run_global_variable
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
        AND bc.cod_run_bacap = code_run_global_variable
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
        code_run_global_variable
      FROM
        lmp.lmp_bas_capacities bc1
      WHERE
        bc1.statn_bas_station_id = i.statn_bas_station_id
        AND bc1.cod_run_bacap = code_run_global_variable
        AND bc1.dat_day_bacap IN (
          SELECT
            c1.Dat_Calde
          FROM
            aac_lmp_calendar_viw c1
          WHERE
            c1.v_Dat_Calde_In_6 = i.val_month_dbdin
        );

    END LOOP;
end;

procedure update_succed_final_prc is
  begin
    UPDATE
      lmp_bas_model_run_stats m
    SET
      m.dat_end_mosta = SYSDATE,
      m.sta_step_mosta = 'پايان موفق'
    WHERE
      m.cod_run_mosta = code_run_global_variable
      AND m.num_step_mosta = 1
      AND m.num_module_mosta = history_record_global.module;  
end;


procedure fill_cap_dbd_inputs_prc is
  lv_month_next VARCHAR2(6);
  begin
    fill_bas_fix_params_prc();

    update_bas_fix_params_prc();

    app_lmp_cap_reports_pkg.set_fix_ton_user_prc;

    COMMIT;

    fill_cap_dbd_inputs_fix_tonday_prc();

    lv_month_next := calc_month_next_fun();

    fill_CAP_DBD_INP_tot-station_prc(lv_month_next);

    fill_CAP_DBD_INP_tot-st_og_prc( lv_month_next);

    fill_CAP_DBD_INP_tot_st_day_1_prc();

    fill_CAP_DBD_INP_tot_st_day_2_prc();

    fill_CAP_DBD_INP_tot_st_day_3_prc();

    update_succed_final_prc();
    --  prc call 2
    update_model_stat_step_prc(
      p_num_step = > 1,
      P_NUM_MODULE = > history_record_global.module,
      p_flg_stat = > 1
    );

    COMMIT;
end;
