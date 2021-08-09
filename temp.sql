FUNCTION calculate_cap_heat_temp_fun(
  pr_dat_calde   in date,
  pr_num_furnace in lmp.lmp_bas_fix_params.val_att1_lmpfp%type,
  pr_pdw         in lmp.lmp_bas_fix_params.val_att2_lmpfp%type,
  pr_iu          in lmp.lmp_bas_fix_params.val_att7_lmpfp%type
  ) return number IS
  lv_stop is number;
  
  begin
    SELECT
      nvl(SUM(nvl(fp.val_att7_lmpfp, 0) + nvl(fp.val_att8_lmpfp, 0)), 0) 
    INTO lv_stop
    FROM
      lmp.lmp_bas_fix_params fp
    WHERE
      fp.lkp_typ_lmpfp = 'FURNACE_STOP'
      AND fp.val_att1_lmpfp = pr_num_furnace
      AND fp.dat_att_lmpfp = pr_dat_calde;

    EXCEPTION
      WHEN no_data_found THEN lv_stop := 0;
    END;

    return (24 - lv_stop) * i.pr_iu * i.pr_pdw;
    
end;

PROCEDURE insert_cap_heat_temp_prc(
  pr_cap_heat_temp in number,
  pr_dat_calde     in date,
  pr_num_furnace   in number) IS
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
      pr_dat_calde,
      code_run_global_variable,
      pr_num_furnace,
      pr_cap_heat_temp,
      'تعداد'
    );
  
end;

PROCEDURE insert_cap_heat_prc(
  pr_cap_heat      in number,
  pr_dat_calde     in date) IS
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
        pr_dat_calde,
        code_run_global_variable,
        pr_cap_heat
      ); 
  
end;

PROCEDURE calculate_cap_heat_prc(
  pr_dat_calde in date) IS
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
        lv_cap_heat_temp := calculate_cap_heat_temp_fun(pr_dat_calde, num_furnace, pdw, iu);

        -- insert capacity heat of each parameter in a specific date to lmp.lmp_cap_heat_plans 
        insert_cap_heat_temp_prc( cap_heat_temp , pr_dat_calde, num_furnace);

        -- calculate capacity sum of heats in a specific date
        lv_cap_heat := lv_cap_heat + lv_cap_heat_temp;

    END LOOP;

    -- insert capacity total heat of all parameters  a specific date to lmp.lmp_bas_capacities
    insert_cap_heat_prc( lv_cap_heat, pr_dat_calde);
end;




PROCEDURE calculate_capacity_prc
 IS 
  lv_dat_start_smc DATE;

  lv_cap_temp NUMBER;
  lv_cap NUMBER;

  lv_pcn_nc_slab NUMBER := 0;
  lv_pcn_du_slab NUMBER := 0;

  lv_3heat_coef NUMBER := 0.95;
  lv_2heat_coef NUMBER := 0.69;
  lv_avail_inv NUMBER;
  lv_min_inv_cap NUMBER;
  lv_pcn_cap NUMBER;
  lv_last_hsm_time DATE ;

  BEGIN

    
    lv_last_hsm_time := apps.api_mas_run_simulators_pkg.return_hsm_available_time_fun;

    -- calculate_cap_heat
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
      
      calculate_cap_heat_prc(j.dat_calde);

    END LOOP;
    --end of calculate_cap_heat

    -- FOR i IN (
      --   SELECT
      --     t.val_att1_lmpfp AS num_furnace,
      --     t.val_att2_lmpfp AS pdw,
      --     t.val_att7_lmpfp AS iu
      --   FROM
      --     lmp.lmp_bas_fix_params t
      --   WHERE
      --     t.lkp_typ_lmpfp = 'FURNACE_CAPACITY'
      -- )
      -- LOOP
      --   BEGIN
      --     SELECT
      --       nvl(SUM(nvl(fp.val_att7_lmpfp, 0) + nvl(fp.val_att8_lmpfp, 0)), 0) 
      --     INTO lv_stop
      --     FROM
      --       lmp.lmp_bas_fix_params fp
      --     WHERE
      --       fp.lkp_typ_lmpfp = 'FURNACE_STOP'
      --       AND fp.val_att1_lmpfp = i.num_furnace
      --       AND fp.dat_att_lmpfp = j.dat_calde;

      --     EXCEPTION
      --       WHEN no_data_found THEN lv_stop := 0;
      --     END;

      --     lv_cap_heat_temp := (24 - lv_stop) * i.iu * i.pdw;

      --   INSERT INTO
      --     lmp.lmp_cap_heat_plans (
      --       cap_heat_plan_id,
      --       dat_day_hetpl,
      --       cod_run_hetpl,
      --       num_furnace_hetpl,
      --       QTY_MAX_TON_HETPL,
      --       LKP_TYP_HETPL
      --     )
      --   VALUES
      --     (
      --       lmp.lmp_cap_heat_plans_seq.nextval,
      --       j.dat_calde,
      --       code_run_global_variable,
      --       i.num_furnace,
      --       lv_cap_heat_temp,
      --       'تعداد'
      --     );

      --  lv_cap_heat := lv_cap_heat + lv_cap_heat_temp;

      -- END LOOP;

      --   INSERT INTO
      --     lmp.lmp_bas_capacities (
      --       bas_capacity_id,
      --       statn_bas_station_id,
      --       dat_day_bacap,
      --       cod_run_bacap,
      --       qty_capacity_bacap
      --     )
      --   VALUES
      --     (
      --       lmp.lmp_bas_capacities_seq.nextval,
      --       NULL,
      --       j.dat_calde,
      --       code_run_global_variable,
      --       lv_cap_heat
      --     );

    -- END LOOP;


    FOR d IN (
      SELECT
        C.Dat_Calde
      FROM
        aac_lmp_calendar_viw C
      WHERE
        C.Dat_Calde BETWEEN history_record_global.dat_start
        AND history_record_global.dat_end
    )
    LOOP




      --CCM
      -- ! calculate lv_cap in specific date
      lv_cap := 0;
      -- ! C.Dat_Calde???????????????//
      FOR t IN (
        SELECT
          t1.bas_station_id,
          nvl(t1.val_prod_modifier_statn, 0) AS val_prod_modifier_statn,
          nvl(t2.qty_maintenace_camai, 0) AS qty_maintenace_camai
        FROM
          (
            SELECT *
            FROM(
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
                  C.Dat_Calde = d.dat_calde
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
              m.dat_day_camai = d.dat_calde
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
      -- ! calculate lv_cap in specific date

      -- ! insert into lmp.lmp_bas_capacities
      -- ! lv_pcn_du_slab + lv_pcn_nc_slab are both 0??????????????????
      lv_dat_start_smc := apps.api_mas_lmp_pkg.get_max_dat_prog_smc_Fun(apps.api_mas_models_pkg.Get_Last_AAS_Cod_Run_Fun);
      IF d.dat_calde > lv_dat_start_smc THEN
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
            d.dat_calde,
            round(
              lv_cap * ((100 - (lv_pcn_du_slab + lv_pcn_nc_slab)) / 100),
              3
            ),
            code_run_global_variable
          );

      END IF;
      -- ! end of insert into lmp.lmp_bas_capacities




      --Send to HSM
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
                  C.Dat_Calde = d.dat_calde
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
              m.dat_day_camai = d.dat_calde
          ) t2
        WHERE
          t1.dat_calde = t2.dat_day_camai(+)
          AND t1.bas_station_id = t2.statn_bas_station_id(+)
      )
      LOOP
        IF trunc(d.Dat_Calde) = trunc(SYSDATE) THEN lv_cap_temp := (
          greatest(
            t.qty_prod_cap_statn * ((18.5 - (SYSDATE - trunc(SYSDATE)) * 24) / 24),
            0
          ) * t.val_prod_modifier_statn
        );

        ELSE lv_cap_temp := (
          greatest(
            t.qty_prod_cap_statn * (1 - (t.qty_maintenace_camai / 24)),
            0
          ) * t.val_prod_modifier_statn
        );

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
            d.dat_calde,
            lv_cap_temp,
            code_run_global_variable
          );

      END LOOP;









      --HSM
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
                  C.Dat_Calde = d.dat_calde
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
              m.dat_day_camai = d.dat_calde
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

        ----------------------------------Calc_Available----Added by Hr.Ebrahimi 13991204--Edited 14000218
        IF t.arstu_ide_pk_arstu = 'M.S.C CO/M.S.C/HSM/HSM1' THEN 
          IF (
            (trunc(d.Dat_Calde) + 18.5 / 24) <= lv_last_hsm_time
            /*apps.api_mas_run_simulators_pkg.return_hsm_available_time_fun*/
          ) THEN lv_pcn_cap := 0;

          ELSIF (
            (trunc(d.Dat_Calde) + 18.5 / 24) > lv_last_hsm_time
            /*apps.api_mas_run_simulators_pkg.return_hsm_available_time_fun*/
            )
            AND(
              (trunc(d.Dat_Calde - 1) + 18.5 / 24) < lv_last_hsm_time
              /*apps.api_mas_run_simulators_pkg.return_hsm_available_time_fun*/
            ) THEN lv_pcn_cap :=(
              (trunc(d.Dat_Calde) + 18.5 / 24) - greatest(
                (trunc(d.Dat_Calde - 1) + 18.5 / 24),
                lv_last_hsm_time
                /*apps.api_mas_run_simulators_pkg.return_hsm_available_time_fun*/
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
                d.dat_calde,
                greatest(
                  round(
                    lv_pcn_cap * lv_cap_temp * ((100 - lv_pcn_du_slab) / 100),
                    3
                  ),
                  0
                ),
                --greatest(round(1*lv_cap_temp * ((100 - lv_pcn_du_slab) / 100), 3),0),
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
              d.dat_calde,
              lv_cap_temp,
              code_run_global_variable
            );

        END IF;

      END LOOP;







      --CRM
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
                  AND pa.arstu_ide_pk_arstu LIKE 'M.S.C CO/M.S.C/CCM%'
              ),
              (
                SELECT
                  C.Dat_Calde
                FROM
                  aac_lmp_calendar_viw C
                WHERE
                  C.Dat_Calde = d.dat_calde
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
              m.dat_day_camai = d.dat_calde
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
            d.dat_calde,
            lv_cap_temp,
            code_run_global_variable
          );

      END LOOP;









      --SHP
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
            d.dat_calde,
            lv_cap_temp,
            code_run_global_variable
          );

      END LOOP;






    END LOOP;
















      --min_inventory
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

END;