CREATE OR REPLACE PACKAGE BODY "APP_LMP_CAP_HEDAYAT_PKG" IS
  -----------------------------------------------------------
  -------Created by H.Ebrahimi   1399/07/19
  procedure CAP_TARGET_INV_OG_PRC(p_month in varchar2,
                                  p_pcn   in number,
                                  p_qty   in number) is
  
    -- lv_lkp_default     varchar2(50) := 'CAP_TARGET_INV';
    lv_lkp_inv_og      varchar2(50) := 'SOP_INV_OG';
    lv_lkp_inv_station varchar2(50) := 'SOP_INV_STATION';
    lv_cod_run         varchar2(15) := '0';
    lv_station_id      number(15) := 45;
    lv_inv_station     number(15, 3);
    lv_plan_tot        number(15, 3);
    lv_target_inv      number(15, 3);
    lv_cnt             number;
  begin
    select sum(t.qty_prod_plan_dayby)
      into lv_plan_tot
      from lmp.lmp_bas_day_by_days t
     where t.statn_bas_station_id = lv_station_id
       and to_char(t.dat_day_dayby, 'YYYYMM', 'nls_calendar=persian') =
           p_month
       and t.cod_ord_grp_dayby >= 21
       and t.cod_ord_grp_dayby not in (40, 50);
  
    select i.qty_plan_lsinv
      into lv_inv_station
      from lmp.lmp_sop_inventories i
     where i.val_month_lsinv = p_month
       and i.lkp_type_lsinv = lv_lkp_inv_station
       and i.statn_bas_station_id = lv_station_id;
   
  
      
    for og in (select t.cod_ord_grp_dayby as cod_og,
                      sum(t.qty_prod_plan_dayby) as plan_og
                 from lmp.lmp_bas_day_by_days t
                where t.statn_bas_station_id = 45
                  and to_char(t.dat_day_dayby,
                              'YYYYMM',
                              'nls_calendar=persian') = p_month
                  and t.cod_ord_grp_dayby >= 21
                  and t.cod_ord_grp_dayby not in (40, 50)
                group by t.cod_ord_grp_dayby) loop
    
      if p_pcn is not null then
        lv_target_inv := round(((og.plan_og * lv_inv_station * p_pcn / 100) /
                               lv_plan_tot) / 100,
                               0) * 100;
      else
        lv_target_inv := round(((og.plan_og * p_qty) / lv_plan_tot) / 100,
                               0) * 100;
      end if;
    
    select count(1)
      into lv_cnt
      from lmp.lmp_sop_inventories i
      where i.val_month_lsinv=p_month
      and i.lkp_type_lsinv = lv_lkp_inv_og
      and i.statn_bas_station_id = lv_station_id
      and i.cod_order_group_lsinv = og.cod_og;
      
    if lv_cnt=0 then
       insert into lmp.lmp_sop_inventories i
       (sop_inventory_id,
       cod_run_lsinv,
       qty_default_lsinv ,
       statn_bas_station_id,
       cod_order_group_lsinv,
       lkp_type_lsinv,
       val_month_lsinv      
       )
        values
        (lmp.lmp_sop_inventories_seq.NEXTVAL,
        '0',
        lv_target_inv,
         lv_station_id,
         og.cod_og,
         lv_lkp_inv_og,
         p_month
         );
         
      else
        
      update lmp.lmp_sop_inventories s
         set s.qty_default_lsinv = lv_target_inv
       where s.statn_bas_station_id = lv_station_id
         and s.cod_order_group_lsinv = og.cod_og
         and s.lkp_type_lsinv = lv_lkp_inv_og
         and s.val_month_lsinv = p_month;
    
    end if;
    end loop;
    commit;
  end;

  ------------------------------------------------------
  FUNCTION CREATE_COD_RUN_MAS_FUN(p_mas_run_id in number,
                                  p_num_module in number,
                                  P_DES        IN VARCHAR2) RETURN VARCHAR2 IS
    V_CODE_RUN       VARCHAR2(13);
    lv_dat_start     date;
    lv_dat_end       date;
    lv_cnt           number;
    lv_last_plan_dat date;
  BEGIN
    select count(1)
      into lv_cnt
      from lmp_bas_run_histories t
     where t.COD_RUN_RNHIS like
           ('CPM' || to_char(sysdate, 'YYYYMMDD') || '%');
    lv_cnt     := lv_cnt + 1;
    V_CODE_RUN := TO_CHAR(SYSDATE, 'YYYYMMDD') * 100 + lv_cnt;
    V_CODE_RUN := 'CPM' || V_CODE_RUN;
  
    select trunc(mh.dat_str_horizon_mrhis), trunc(mh.dat_end_horizon_mrhis)
      into lv_dat_start, lv_dat_end
      from mas_msch_run_histories mh
     where mh.msch_run_history_id = p_mas_run_id;
  
    select max(cc.Dat_Calde)
      into lv_last_plan_dat
      from aac_lmp_calendar_viw cc
     where cc.v_Dat_Calde_In_6 =
           (select c.v_Dat_Calde_In_6
              from aac_lmp_calendar_viw c
             where c.Dat_Calde = lv_dat_start);
  
    INSERT INTO LMP_BAS_RUN_HISTORIES
      (BAS_RUN_HISTORY_ID,
       COD_RUN_RNHIS,
       DAT_RUN_RNHIS,
       NUM_MODULE_RNHIS,
       STA_RUN_RNHIS,
       DAT_STRT_HRZN_RNHIS,
       DAT_END_HRZN_RNHIS,
       VAL_RUN_RNHIS,
       DES_DESCRIPTION_RNHIS,
       LKP_GROUP_RNHIS,
       MRHIS_MSCH_RUN_HISTORY_ID,
       STA_CNFRM_RNHIS,
       DAT_LAST_PLAN_RNHIS)
    VALUES
      (LMP_BAS_RUN_HISTORIES_SEQ.NEXTVAL,
       V_CODE_RUN,
       SYSDATE,
       p_num_module,
       0,
       lv_dat_START,
       lv_dat_END,
       TO_CHAR(SYSDATE, 'YYYYMMDD'),
       P_DES,
       'LMP',
       p_mas_run_id,
       0,
       lv_last_plan_dat);
    /*APP_LMP_CAP_TOT_MODEL_PKG.insert_model_steps_prc(p_cod_run    => V_CODE_RUN,
    p_num_module => p_num_module);*/
    /*lmp_fill_cap_plan_prc(p_cod_run    => V_CODE_RUN,
    p_num_modue  => p_num_module,
    p_start_date => lv_dat_start,
    p_end_date   => lv_dat_end);*/
  
    /*insert into lmp_bas_camp_plans
    (bas_camp_plan_id,
     statn_bas_station_id,
     dat_day_cmppl,
     cmpdf_bas_camp_define_id,
     cod_run_cmppl)
    select lmp_bas_camp_plans_seq.nextval,
           c.statn_bas_station_id,
           c.dat_day_cmppl,
           c.cmpdf_bas_camp_define_id,
           V_CODE_RUN
      from lmp_bas_camp_plans c
     where c.cod_run_cmppl = '0'
       and c.dat_day_cmppl between lv_dat_start and lv_dat_end;*/
  
    COMMIT;
    RETURN V_CODE_RUN;
  END;

  ---------------------------------------------------------------------------------
  procedure insert_model_steps_prc(p_cod_run    in varchar2,
                                   p_num_module in number) is
    lv_msg1 varchar2(500);
    lv_msg2 varchar2(500);
  begin
    select fp.val_att3_lmpfp
      into lv_msg1
      from lmp.lmp_bas_fix_params fp
     where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
       and fp.val_att1_lmpfp = 5;
    select fp.val_att3_lmpfp
      into lv_msg2
      from lmp.lmp_bas_fix_params fp
     where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
       and fp.val_att1_lmpfp = 3;
    insert into lmp_bas_model_run_stats
      (bas_model_run_stat_id,
       cod_run_mosta,
       num_step_mosta,
       des_step_mosta,
       sta_step_mosta,
       dat_start_mosta,
       dat_end_mosta,
       num_module_mosta)
    values
      (lmp_bas_model_run_stats_seq.nextval,
       p_cod_run,
       1,
       lv_msg1,
       lv_msg2,
       sysdate,
       sysdate + interval '15' second,
       p_num_module);
  
    select fp.val_att3_lmpfp
      into lv_msg1
      from lmp.lmp_bas_fix_params fp
     where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
       and fp.val_att1_lmpfp = 6;
  
    insert into lmp_bas_model_run_stats
      (bas_model_run_stat_id,
       cod_run_mosta,
       num_step_mosta,
       des_step_mosta,
       sta_step_mosta,
       dat_start_mosta,
       dat_end_mosta,
       num_module_mosta)
    values
      (lmp_bas_model_run_stats_seq.nextval,
       p_cod_run,
       2,
       lv_msg1,
       lv_msg2,
       sysdate + interval '15' second,
       sysdate + interval '1' minute,
       p_num_module);
  
    select fp.val_att3_lmpfp
      into lv_msg1
      from lmp.lmp_bas_fix_params fp
     where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
       and fp.val_att1_lmpfp = 7;
  
    insert into lmp_bas_model_run_stats
      (bas_model_run_stat_id,
       cod_run_mosta,
       num_step_mosta,
       des_step_mosta,
       sta_step_mosta,
       dat_start_mosta,
       dat_end_mosta,
       num_module_mosta)
    values
      (lmp_bas_model_run_stats_seq.nextval,
       p_cod_run,
       3,
       lv_msg1,
       lv_msg2,
       sysdate + interval '1' minute,
       sysdate + interval '72' second,
       p_num_module);
  end;
  ---------------------------------------------------------------
  procedure insert_production_plan_pf_prc(p_pf_id       in number,
                                          p_st_id       in number,
                                          p_day         in varchar2,
                                          p_qty_prod    in number,
                                          p_cod_run     in varchar2,
                                          p_flg_pur     in number,
                                          p_order_group in varchar2,
                                          p_cod_mix     in number,
                                          p_dat_last    in varchar2) is
    v_string   varchar2(2000);
    lv_cod_mix number;
  begin
    if p_cod_mix = 0 then
      lv_cod_mix := null;
    else
      lv_cod_mix := p_cod_mix;
    end if;
    begin
      --execute immediate 'alter session set nls_calendar=''persian''';
      v_string := 'INSERT INTO lmp.lmp_bas_production_plan_pfs (bas_production_plan_pf_id,cod_profm_prppf,cod_run_prppf,
    cod_statn_prppf,num_module_prppf,qty_prod_prppf,DAT_DAY_PRPPF,FLG_PRCHS_PRPPF,COD_ORDER_GROUP_PRPPF,mixcm_bas_mix_combination_id,VAL_DAT_LAST_PRPPF) VALUES
    (lmp.lmp_bas_production_plan_pf_seq.nextval,:cod_pf,:cod_run,:cod_st,3,:qty_prod,:day,:flg_pur,:cod_ord_grp,:cod_mix,:val_datlast)';
      execute immediate v_string
        using p_pf_id, p_cod_run, p_st_id, p_qty_prod, to_date(p_day, 'YYYYMMDD', 'nls_calendar=persian'), p_flg_pur, p_order_group, lv_cod_mix, p_dat_last;
    exception
      when others then
        lv_cod_mix := null;
        v_string   := 'INSERT INTO lmp.lmp_bas_production_plan_pfs (bas_production_plan_pf_id,cod_profm_prppf,cod_run_prppf,
    cod_statn_prppf,num_module_prppf,qty_prod_prppf,DAT_DAY_PRPPF,FLG_PRCHS_PRPPF,COD_ORDER_GROUP_PRPPF,mixcm_bas_mix_combination_id,VAL_DAT_LAST_PRPPF) VALUES
    (lmp.lmp_bas_production_plan_pf_seq.nextval,:cod_pf,:cod_run,:cod_st,3,:qty_prod,:day,:flg_pur,:cod_ord_grp,:cod_mix,:val_datlast)';
        execute immediate v_string
          using p_pf_id, p_cod_run, p_st_id, p_qty_prod, to_date(p_day, 'YYYYMMDD', 'nls_calendar=persian'), p_flg_pur, p_order_group, lv_cod_mix, p_dat_last;
    end;
  end;

  procedure insert_production_pf_test_prc(p_pf_id       in number,
                                          p_st_id       in number,
                                          p_day         in varchar2,
                                          p_qty_prod    in number,
                                          p_cod_run     in varchar2,
                                          p_flg_pur     in number,
                                          p_order_group in varchar2,
                                          p_cod_mix     in number,
                                          p_dat_last    in varchar2,
                                          p_cod_product in number) is
    v_string   varchar2(2000);
    lv_cod_mix number;
  begin
    if p_cod_mix = 0 then
      lv_cod_mix := null;
    else
      lv_cod_mix := p_cod_mix;
    end if;
    begin
      --execute immediate 'alter session set nls_calendar=''persian''';
      v_string := 'INSERT INTO lmp.lmp_bas_production_plan_pfs (bas_production_plan_pf_id,cod_profm_prppf,cod_run_prppf,
    cod_statn_prppf,num_module_prppf,qty_prod_prppf,DAT_DAY_PRPPF,FLG_PRCHS_PRPPF,COD_ORDER_GROUP_PRPPF,mixcm_bas_mix_combination_id,VAL_DAT_LAST_PRPPF,COD_PRODUCT_PRPPF) VALUES
    (lmp.lmp_bas_production_plan_pf_seq.nextval,:cod_pf,:cod_run,:cod_st,3,:qty_prod,:day,:flg_pur,:cod_ord_grp,:cod_mix,:val_datlast,:cod_product)';
      execute immediate v_string
        using p_pf_id, p_cod_run, p_st_id, p_qty_prod, to_date(p_day, 'YYYYMMDD', 'nls_calendar=persian'), p_flg_pur, p_order_group, lv_cod_mix, p_dat_last, p_cod_product;
    exception
      when others then
        lv_cod_mix := null;
        v_string   := 'INSERT INTO lmp.lmp_bas_production_plan_pfs (bas_production_plan_pf_id,cod_profm_prppf,cod_run_prppf,
    cod_statn_prppf,num_module_prppf,qty_prod_prppf,DAT_DAY_PRPPF,FLG_PRCHS_PRPPF,COD_ORDER_GROUP_PRPPF,mixcm_bas_mix_combination_id,VAL_DAT_LAST_PRPPF,COD_PRODUCT_PRPPF) VALUES
    (lmp.lmp_bas_production_plan_pf_seq.nextval,:cod_pf,:cod_run,:cod_st,3,:qty_prod,:day,:flg_pur,:cod_ord_grp,:cod_mix,:val_datlast,:cod_product)';
        execute immediate v_string
          using p_pf_id, p_cod_run, p_st_id, p_qty_prod, to_date(p_day, 'YYYYMMDD', 'nls_calendar=persian'), p_flg_pur, p_order_group, lv_cod_mix, p_dat_last, p_cod_product;
    end;
  end;

  ----------------------------------------------------------------------------
  procedure insert_transport_plan_prc(p_pf_id       in number,
                                      p_st1_id      in number,
                                      p_st2_id      in number,
                                      p_day         in varchar2,
                                      p_qty_prod    in number,
                                      p_cod_run     in varchar2,
                                      p_order_group in varchar2,
                                      p_pcn_nc      in number) is
  begin
    insert into lmp_bas_transport_plans
      (bas_transport_plan_id,
       cod_profm_trapl,
       cod_run_trapl,
       cod_statn_from_trapl,
       cod_statn_to_trapl,
       num_module_trapl,
       qty_tranport_trapl,
       DAT_DAY_TRAPL,
       COD_ORDER_GROUP_TRAPL,
       PCN_NC_TRAPL)
    values
      (lmp_bas_transport_plans_seq.nextval,
       p_pf_id,
       p_cod_run,
       p_st1_id,
       p_st2_id,
       3,
       p_qty_prod,
       to_date(p_day, 'YYYYMMDD', 'nls_calendar=persian'),
       p_order_group,
       p_pcn_nc);
  
  end;
  -------------------------------------------------------------------------------------------
  FUNCTION CREATE_COD_RUN_FUN(p_dat_start IN DATE,
                              P_dat_end   IN DATE,
                              p_des       in varchar2) RETURN varchar2 IS

    V_CODE_RUN       LMP_BAS_RUN_HISTORIES.COD_RUN_RNHIS%type;
    lv_cnt           number;
    lv_last_plan_dat date;
    lv_MAS_RUN_ID    Mas_Msch_Run_Histories.Msch_Run_History_Id%type;


  BEGIN
    select count(1)
      into lv_cnt
      from lmp_bas_run_histories t
     where t.COD_RUN_RNHIS like
           ('CAP' || to_char(sysdate, 'YYYYMMDD') || '%');
    lv_cnt     := lv_cnt + 1;
    V_CODE_RUN := TO_CHAR(SYSDATE, 'YYYYMMDD') * 100 + lv_cnt;
    V_CODE_RUN := 'CAP' || V_CODE_RUN;
  
  --WHAT IS LAST DAY OF CURENT MONTH?
    select max(cc.Dat_Calde)
      into lv_last_plan_dat
      from aac_lmp_calendar_viw cc
     where cc.v_Dat_Calde_In_6 =
           (select c.v_Dat_Calde_In_6
              from aac_lmp_calendar_viw c
             where c.Dat_Calde = trunc(p_dat_start));
  
  --LAST EXECUTION RUN NUMBER OF MASTER MODEL
    Select Max(t.Msch_Run_History_Id) as Msch_Run_History_Id
      into lv_MAS_RUN_ID
      From mas.Mas_Msch_Run_Histories t
     Where Nvl(t.Num_Module_Mrhis, 1) = 20
       and t.lkp_sta_model_mrhis = 'SUCCESSFUL';
  
  --
    INSERT INTO LMP_BAS_RUN_HISTORIES
      (BAS_RUN_HISTORY_ID,
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
       mrhis_msch_run_history_id)
    VALUES
      (LMP_BAS_RUN_HISTORIES_SEQ.NEXTVAL,
       V_CODE_RUN,
       SYSDATE,
       3,
       0,
       p_dat_START,
       p_dat_END,
       TO_CHAR(SYSDATE, 'YYYYMMDD'),
       P_DES,
       'LMP',
       1,
       lv_last_plan_dat,
       lv_MAS_RUN_ID);
  
    COMMIT;
    RETURN V_CODE_RUN;
  END;

  --------------------------created by s.boosaiedi 98/05/20
  FUNCTION CREATE_COD_RUN_TOT_FUN RETURN VARCHAR2 IS
    V_CODE_RUN VARCHAR2(13);
    lv_cnt     number;
  BEGIN
    select count(1)
      into lv_cnt
      from lmp_bas_run_histories t
     where t.COD_RUN_RNHIS like
           ('TOT' || to_char(sysdate, 'YYYYMMDD') || '%');
    lv_cnt     := lv_cnt + 1;
    V_CODE_RUN := TO_CHAR(SYSDATE, 'YYYYMMDD') * 100 + lv_cnt;
    V_CODE_RUN := 'TOT' || V_CODE_RUN;
  
    INSERT INTO LMP_BAS_RUN_HISTORIES
      (BAS_RUN_HISTORY_ID,
       COD_RUN_RNHIS,
       DAT_RUN_RNHIS,
       NUM_MODULE_RNHIS,
       STA_RUN_RNHIS,
       sta_cnfrm_final_rnhis,
       DAT_STRT_HRZN_RNHIS,
       DAT_END_HRZN_RNHIS,
       VAL_RUN_RNHIS,
       DES_DESCRIPTION_RNHIS,
       LKP_GROUP_RNHIS,
       FLG_IN_RUN_RNHIS)
    VALUES
      (LMP_BAS_RUN_HISTORIES_SEQ.NEXTVAL,
       V_CODE_RUN,
       SYSDATE,
       0,
       0,
       1,
       null,
       null,
       TO_CHAR(SYSDATE, 'YYYYMMDD'),
       null,
       'LMP',
       1);
  
    COMMIT;
    RETURN V_CODE_RUN;
  END;
  --------------------------created by s.boosaiedi 98/07/03
  FUNCTION CREATE_COD_RUN_TOT_FUN2 RETURN VARCHAR2 IS
    V_CODE_RUN VARCHAR2(13);
    lv_cnt     number;
  BEGIN
    select count(1)
      into lv_cnt
      from lmp_bas_run_histories t
     where t.COD_RUN_RNHIS like
           ('TOT' || to_char(sysdate, 'YYYYMMDD') || '%');
    lv_cnt     := lv_cnt + 1;
    V_CODE_RUN := TO_CHAR(SYSDATE, 'YYYYMMDD') * 100 + lv_cnt;
    V_CODE_RUN := 'TOT' || V_CODE_RUN;
  
    INSERT INTO LMP_BAS_RUN_HISTORIES
      (BAS_RUN_HISTORY_ID,
       COD_RUN_RNHIS,
       DAT_RUN_RNHIS,
       NUM_MODULE_RNHIS,
       STA_RUN_RNHIS,
       DAT_STRT_HRZN_RNHIS,
       DAT_END_HRZN_RNHIS,
       VAL_RUN_RNHIS,
       DES_DESCRIPTION_RNHIS,
       LKP_GROUP_RNHIS,
       FLG_IN_RUN_RNHIS)
    VALUES
      (LMP_BAS_RUN_HISTORIES_SEQ.NEXTVAL,
       V_CODE_RUN,
       SYSDATE,
       0,
       0,
       null,
       null,
       TO_CHAR(SYSDATE, 'YYYYMMDD'),
       null,
       'LMP',
       1);
  
    COMMIT;
    RETURN V_CODE_RUN;
  END;
  --------------------------------------------------------------------------------------------
  procedure insert_order_plan_prc(p_cod_ord    in varchar2,
                                  p_num_item   number,
                                  p_pf_id      in number,
                                  p_cod_run    in varchar2,
                                  p_pcn_comp   in number,
                                  p_qty_rem    in number,
                                  p_tot_delay  in number,
                                  p_duedate    in varchar2,
                                  p_qty_demand in number) is
  begin
    --execute immediate 'alter session set nls_calendar=''persian''';
    insert into lmp_sop_order_plans
      (sop_order_plan_id,
       cod_order_hdr_ordpn,
       num_order_item_ordpn,
       flg_db_order_ordpn,
       cod_profm_ordpn,
       cod_run_ordpn,
       pcn_completion_ordpn,
       qty_remaining_order_ordpn,
       tot_delay_ordpn,
       val_duedate_ordpn,
       QTY_NEED_HSM_ORDPN)
    values
      (lmp_sop_order_plans_seq.nextval,
       p_cod_ord,
       p_num_item,
       0,
       p_pf_id,
       p_cod_run,
       p_pcn_comp,
       p_qty_rem,
       p_tot_delay,
       p_duedate,
       p_qty_demand);
  end;
  ---------------------------------------------------------------------------
  procedure insert_sale_plan_prc(p_cod_ord  in varchar2,
                                 p_num_item number,
                                 p_period   in varchar2,
                                 p_qty      in number,
                                 p_cod_run  in varchar2) is
    lv_cod_ord_group varchar2(2);
  begin
    --execute immediate 'alter session set nls_calendar=''persian''';
    insert into lmp_sop_sale_plans
      (sop_sale_plan_id,
       cod_order_salpl,
       num_item_salpl,
       DAT_DAY_SALPL,
       qty_sale_salpl,
       cod_run_salpl)
    values
      (lmp_sop_sale_plans_seq.nextval,
       p_cod_ord,
       p_num_item,
       to_date(p_period, 'YYYYMMDD', 'nls_calendar=persian'),
       p_qty,
       p_cod_run);
  
    /*select o.cod_order_group_lmpor
      into lv_cod_ord_group
      from lmp.lmp_bas_orders o
     where o.cod_run_lmpor = p_cod_run
       and o.cod_order_lmpor = p_cod_ord
       and o.num_order_lmpor = p_num_item
       and o.flg_db_order_lmpor = 0;
    
    if lv_cod_ord_group between '23' and '31' then
      insert into lmp.lmp_cap_inventories
        (cap_inventory_id,
         cod_run_capin,
         cod_ord_capin,
         num_item_capin,
         cod_station1_capin,
         dat_ent_capin,
         qty_kg_capin,
         lkp_typ_inv_capin)
      values
        (lmp.lmp_cap_inventories_seq.nextval,
         p_cod_run,
         p_cod_ord,
         p_num_item,
         0,
         to_date(p_period, 'YYYYMMDD', 'nls_calendar=persian'),
         p_qty,
         'OUTPUT_FIRST');
    end if;*/
  end;
  --------------------------------------------------------------------------------
  procedure insert_prod_plan_ord_prc(p_cod_ord    in varchar2,
                                     p_num_item   number,
                                     p_period     in varchar2,
                                     p_qty        in number,
                                     p_cod_run    in varchar2,
                                     p_station_id in number) is
  begin
    --execute immediate 'alter session set nls_calendar=''persian''';
    insert into lmp_sop_prod_plan_orders
      (sop_prod_plan_order_id,
       cod_order_ppord,
       num_item_ppord,
       cod_station_ppord,
       DAT_DAY_PPORD,
       cod_run_ppord,
       flg_purchase_ppord,
       qty_prod_ppord)
    values
      (lmp_sop_prod_plan_orders_seq.nextval,
       p_cod_ord,
       p_num_item,
       p_station_id,
       to_date(p_period, 'YYYYMMDD', 'nls_calendar=persian'),
       p_cod_run,
       0,
       p_qty);
    commit;
  end;

  --------------------------------------------------------------------------------
  procedure insert_prod_plan_tst_ord_prc(p_cod_ord     in varchar2,
                                         p_num_item    number,
                                         p_period      in varchar2,
                                         p_qty         in number,
                                         p_cod_run     in varchar2,
                                         p_station_id  in number,
                                         p_cod_product in number) is
  begin
    --execute immediate 'alter session set nls_calendar=''persian''';
    insert into lmp_sop_prod_plan_orders
      (sop_prod_plan_order_id,
       cod_order_ppord,
       num_item_ppord,
       cod_station_ppord,
       DAT_DAY_PPORD,
       cod_run_ppord,
       flg_purchase_ppord,
       qty_prod_ppord,
       cod_product_ppord)
    values
      (lmp_sop_prod_plan_orders_seq.nextval,
       p_cod_ord,
       p_num_item,
       p_station_id,
       to_date(p_period, 'YYYYMMDD', 'nls_calendar=persian'),
       p_cod_run,
       0,
       p_qty,
       p_cod_product);
    commit;
  end;
  --------------------------------------------------------------
  procedure update_prod_group_prc(p_group_id in number,
                                  p_qty_plan in number,
                                  p_cod_run  in varchar2) is
  begin
    update lmp.lmp_sop_og_periods t
       set t.qty_plan_daily_ogprd = nvl(p_qty_plan, 0) +
                                    nvl(t.qty_plan_daily_ogprd, 0)
     where t.sop_og_period_id = p_group_id
       and t.cod_run_ogprd = p_cod_run;
  end;
  --------------------------------------------------------------
  procedure create_model_data_prc(p_cod_run in varchar2) is
    lv_dat_start  date;
    lv_dat_end    date;
    lv_month_cur  varchar2(6);
    lv_month_next varchar2(6);
    --lv_msg1      varchar2(500);
    --lv_msg2      varchar2(500);
    lv_num_day        number;
    lv_rem_tot        number;
    lv_num_minues_day number;
    lv_min_inv        number;
    lv_first_inv      number;
    lv_module         number;
    lv_tot_cap        number;
    lv_pdw_ccm        number := 196;
    LV_COUNT          NUMBER;
    LV_CAP_AVLBL_TOT  NUMBER;
    LV_CAP_FURNACE    NUMBER;
    LV_CAP_CASTING    NUMBER;
    LV_FACTOR         NUMBER;
    lv_plan_sch       NUMBER;
    lv_plan           NUMBER;
    lv_dat_start_smc  DATE;
    lv_cod_run_tot    varchar2(15);
    lv_round_base     number;
  begin
  
    select t.dat_strt_hrzn_rnhis, t.dat_end_hrzn_rnhis, t.num_module_rnhis
      into lv_dat_start, lv_dat_end, lv_module
      from lmp_bas_run_histories t
     where t.cod_run_rnhis = p_cod_run;
  
  -- RETURN THE CODE OF TOTAL RUN OF THE CURRENT DAY
    lv_cod_run_tot := app_lmp_cap_tot_model_pkg.ret_cod_run_cap_tot_fun;
  
    app_lmp_cap_tot_model_pkg.update_model_stat_step_prc(p_cod_run     => lv_cod_run_tot,
                                                         p_cod_mjl_run => p_cod_run,
                                                         p_num_step    => 1,
                                                         P_NUM_MODULE  => lv_module,
                                                         p_flg_stat    => 0);
  
       insert into lmp_bas_model_run_stats
      (bas_model_run_stat_id,
       cod_run_mosta,
       num_step_mosta,
       des_step_mosta,
       sta_step_mosta,
       dat_start_mosta,
       num_module_mosta)
    values
      (lmp_bas_model_run_stats_seq.nextval,
       p_cod_run,
       1,
       'آماده سازي داده با شماره اجراي جديد',
       'در حال اجرا',
       sysdate,
       lv_module);
  
    update lmp.lmp_bas_run_histories rh
       set rh.des_status_rnhis = 'RUNNING STEP 1'
     where rh.cod_run_rnhis = p_cod_run
       and rh.num_module_rnhis = lv_module;
    commit;
    insert into lmp_sop_og_periods
      (sop_og_period_id,
       orgrp_sop_order_group_id,
       cod_run_ogprd,
       dat_day_ogprd,
       num_module_ogprd,
       qty_min_daily_ogprd,
       qty_max_daily_ogprd)
      select lmp_sop_og_assigns_seq.nextval,
             ogtt.sop_order_group_id,
             p_cod_run,
             ogtt.dat_calde,
             lv_module,
             case
               when ogpt.qty_min_daily_ogprd is null then
                ogtt.qty_min_daily_orgrp
               else
                ogpt.qty_min_daily_ogprd
             end as qty_min,
             case
               when ogpt.qty_max_daily_ogprd is null then
                ogtt.qty_max_daily_orgrp
               else
                ogpt.qty_max_daily_ogprd
             end as qty_max
        from (select og.sop_order_group_id,
                     c.Dat_Calde,
                     og.qty_min_daily_orgrp,
                     og.qty_max_daily_orgrp
                from lmp_sop_order_groups      og,
                     aac_lmp_calendar_viw      c,
                     lmp_sop_order_group_types ogt
               where ogt.sop_order_group_type_id =
                     og.ogtyp_sop_order_group_type_id
                 and ogt.typ_group_type_ogtyp = 1
                 and c.Dat_Calde between lv_dat_start and lv_dat_end) ogtt,
             (select ogp.orgrp_sop_order_group_id,
                     ogp.dat_day_ogprd,
                     ogp.qty_min_daily_ogprd,
                     ogp.qty_max_daily_ogprd
                from lmp_sop_og_periods ogp
               where ogp.dat_day_ogprd between lv_dat_start and lv_dat_end
                 and ogp.cod_run_ogprd = '0'
                 and ogp.num_module_ogprd = 3) ogpt
       where ogtt.sop_order_group_id = ogpt.orgrp_sop_order_group_id(+)
         and ogtt.dat_calde = ogpt.dat_day_ogprd(+);
  
    insert into lmp_bas_camp_plans
      (bas_camp_plan_id,
       statn_bas_station_id,
       dat_day_cmppl,
       cmpdf_bas_camp_define_id,
       cod_run_cmppl,
       NUM_CAMP_CMPPL)
      select lmp_bas_capacity_plans_seq.nextval,
             p.statn_bas_station_id,
             p.dat_day_cmppl,
             p.cmpdf_bas_camp_define_id,
             p_cod_run,
             p.num_camp_cmppl
        from lmp.lmp_bas_camp_plans p
       where p.cod_run_cmppl = '0'
         and p.dat_day_cmppl between lv_dat_start and lv_dat_end;
  
    --parameters
    insert into lmp_bas_parameters
      (bas_parameter_id,
       cod_run_prmtr,
       nam_ful_far_prmtr,
       nam_ful_latin_prmtr,
       num_module_prmtr,
       typ_cap_prmtr,
       val_parameter_prmtr,
       lkp_group_prmtr)
      select lmp_bas_parameters_seq.nextval,
             p_cod_run,
             p.nam_ful_far_prmtr,
             p.nam_ful_latin_prmtr,
             lv_module,
             p.typ_cap_prmtr,
             p.val_parameter_prmtr,
             p.lkp_group_prmtr
        from lmp_bas_parameters p
       where p.cod_run_prmtr = '0'
         and p.num_module_prmtr = 3
            --and p.typ_cap_prmtr = 'OBJFN'
         and p.lkp_group_prmtr = 'LMP';
  
    /*select fp.val_att3_lmpfp
     into lv_msg2
     from lmp.lmp_bas_fix_params fp
    where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
      and fp.val_att1_lmpfp = 3;*/
  
    insert into lmp_bas_orders
      (bas_order_id,
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
       FLG_FIRTS_ACTIVE_LMPOR)
      select lmp_bas_orders_seq.nextval,
             o.cod_order_lmpor,
             p_cod_run,
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
        from lmp_bas_orders o
       where o.cod_run_lmpor = '00'
      --AND O.LKP_GROUP_LMPOR='LMP'
      ;
  
    -- APP_LMP_CAP_TOT_MODEL_PKG.update_tot_need_order_prc(p_cod_run => p_cod_run);
  
    insert into lmp.lmp_bas_constraints
      (bas_constraint_id,
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
       flg_active_cnstr)
      select lmp.lmp_bas_constraints_seq.nextval,
             m.BAS_CONSTRAINT_ID as master_id,
             m.statn_bas_station_id,
             p_cod_run,
             m.dat_calde,
             lv_module,
             nvl(d.qty_max_day_cnstr, m.qty_max_day_cnstr) as qty_max,
             nvl(d.qty_min_day_cnstr, m.qty_min_day_cnstr) as qty_min,
             m.typ_constraint_cnstr,
             m.typ_stock_flow_cnstr,
             m.ptype_bas_product_type_id,
             m.profm_bas_product_family_id,
             m.cod_constraint_cnstr,
             m.flg_active_cnstr
        from (SELECT T.BAS_CONSTRAINT_ID,
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
                FROM LMP.LMP_BAS_CONSTRAINTS T,
                     (select c.V_DAT_CALDE_IN_8, c.DAT_CALDE
                        from apps.lmp_aac_calendar_viw c
                       where c.DAT_CALDE between lv_dat_start and lv_dat_end) cal
               WHERE T.FLG_ACTIVE_CAP_CNSTR = 1
                 AND T.NUM_MODULE_CNSTR IS NULL) m,
             (SELECT C.BAS_CONSTRAINT_ID,
                     C.CNSTR_BAS_CONSTRAINT_ID,
                     C.Dat_Day_Cnstr,
                     C.QTY_MAX_day_CNSTR,
                     C.QTY_MIN_day_CNSTR
                FROM lmp.LMP_BAS_CONSTRAINTS C, lmp.LMP_BAS_CONSTRAINTS C1
               WHERE C.CNSTR_BAS_CONSTRAINT_ID IS NOT NULL
                 AND C.COD_RUN_CNSTR = '0'
                 AND C.NUM_MODULE_CNSTR = 3
                 AND C1.BAS_CONSTRAINT_ID = C.CNSTR_BAS_CONSTRAINT_ID) d
       where m.BAS_CONSTRAINT_ID = d.cnstr_bas_constraint_id(+)
         and m.dat_calde = d.dat_day_cnstr(+)
         and (m.qty_max_day_cnstr > 0 or m.qty_min_day_cnstr > 0);
    
    
    APP_LMP_CAP_TOT_MODEL_PKG.cal_aas_data_viw_prc (p_cod_run => p_cod_run);---Added By Hr.Ebrahimi 14000219
    
    APP_LMP_CAP_TOT_MODEL_PKG.calculate_capacity_prc(p_cod_run => p_cod_run);
  
    commit;
  
    app_lmp_cap_tot_model_pkg.cal_target_month_prc(p_cod_run => p_cod_run);
  
    insert into lmp.lmp_bas_fix_params
      (bas_fix_param_id,
       val_att1_lmpfp,
       val_att4_lmpfp,
       val_att2_lmpfp,
       dat_att_lmpfp,
       val_att3_lmpfp,
       lkp_typ_lmpfp)
      select lmp.lmp_bas_fix_params_seq.nextval,
             station_id,
             cod_ord_group,
             max_ton,
             Dat_Calde,
             p_cod_run,
             'MAX_TON_DAY'
        from (select t.val_att1_lmpfp as station_id,
                     t.val_att4_lmpfp as cod_ord_group,
                     t.val_att2_lmpfp as max_ton
                from lmp.lmp_bas_fix_params t
               where t.lkp_typ_lmpfp = 'DAY_BY_DAY'
                 and t.val_att1_lmpfp in
                     (41, 45, 68, 67, 65, 66, 77, 78, 79)),
             (select c.Dat_Calde
                from aac_lmp_calendar_viw c
               where c.Dat_Calde between lv_dat_start and lv_dat_end);
  
    update lmp.lmp_bas_fix_params t
       set t.val_att2_lmpfp = t.val_att2_lmpfp * 3
     where t.lkp_typ_lmpfp = 'MAX_TON_DAY'
       and t.dat_att_lmpfp > lv_dat_end - 10
       and t.val_att3_lmpfp = p_cod_run;
  
    app_lmp_cap_reports_pkg.set_fix_ton_user_prc;
    commit;
    insert into lmp.lmp_cap_dbd_inputs
      (CAP_DBD_INPUT_ID,
       DAT_DAY_DBDIN,
       STATN_BAS_STATION_ID,
       COD_ORDER_GROUP_DBDIN,
       QTY_MIN_DBDIN,
       QTY_PLAN_DBDIN,
       QTY_MAX_DBDIN,
       COD_RUN_DBDIN,
       LKP_TYP_DBDIN)
      SELECT lmp.lmp_cap_dbd_inputs_seq.nextval,
             CAP_DBD.DAT_DAY_DBDIN              as date_day,
             CAP_DBD.STATN_BAS_STATION_ID       as station_Id,
             CAP_DBD.COD_ORDER_GROUP_DBDIN      as cod_order_group,
             CAP_DBD.QTY_MIN_DBDIN              as qty_min,
             CAP_DBD.QTY_PLAN_DBDIN             as qty_plan,
             CAP_DBD.QTY_MAX_DBDIN              as qty_max,
             p_cod_run,
             CAP_DBD.LKP_TYP_DBDIN              as lkp_typ
        from LMP.LMP_CAP_DBD_INPUTS CAP_DBD
       where CAP_DBD.LKP_TYP_DBDIN = 'FIX_TON_DAY'
         and CAP_DBD.COD_RUN_DBDIN = '0'
         and cap_dbd.dat_day_dbdin BETWEEN lv_dat_start AND lv_dat_end;
  
    lv_month_cur := to_char(sysdate, 'YYYYMM');
  
    /*select count(c.Dat_Calde)
      into lv_num_day
      from aac_lmp_calendar_viw c
     where c.v_Dat_Calde_In_6 = lv_month_cur
       and c.Dat_Calde >= lv_dat_start
       and nvl((select sum(nvl(m.qty_maintenace_camai, 0) +
                          nvl(m.qty_inactive_camai, 0))
                 from lmp.lmp_cap_maintenances m
                where m.statn_bas_station_id = 45
                  and m.dat_day_camai = c.Dat_Calde),
               0) < 20;
    for og in (select t.val_att1_lmpfp as station_id,
                      t.val_att4_lmpfp as cod_ord_group,
                      t.val_att2_lmpfp as max_ton
                 from lmp.lmp_bas_fix_params t
                where t.lkp_typ_lmpfp = 'DAY_BY_DAY'
                  and t.val_att1_lmpfp in (45)
                  and t.val_att4_lmpfp in
                      ('21', '23', '22', '25', '35', '36')) loop
      -- ('23', '22', '25')) loop
      begin
        select count(t.cap_dbd_input_id)
          into lv_num_minues_day
          from lmp.lmp_cap_dbd_inputs t
         where t.lkp_typ_dbdin = 'FIX_TON_DAY'
           and t.statn_bas_station_id = og.station_id
           and t.cod_run_dbdin = '0'
           and t.cod_order_group_dbdin = og.cod_ord_group
           and t.qty_max_dbdin = 0
           and t.dat_day_dbdin >= lv_dat_start
           and to_char(t.dat_day_dbdin, 'YYYYMM') = lv_month_cur;
        if lv_num_day - lv_num_minues_day = 0 then
          lv_rem_tot := 0;
        else
          select greatest(nvl(t5.qty_max_dbdin, t5.qty_plan_dbdin) /
                          (lv_num_day - lv_num_minues_day),
                          0)
            into lv_rem_tot
            from LMP.LMP_CAP_DBD_INPUTS t5
           where t5.lkp_typ_dbdin = 'TOTAL_STATION_OG'
             and t5.cod_run_dbdin = p_cod_run
             and t5.statn_bas_station_id = og.station_id
             and t5.cod_order_group_dbdin = og.cod_ord_group
             and t5.val_month_dbdin = lv_month_cur;
        end if;
      exception
        when no_data_found then
          continue;
      end;
      if lv_rem_tot is null then
        continue;
      end if;
      update lmp.lmp_bas_fix_params t4
         set t4.val_att2_lmpfp = round(lv_rem_tot * 1.3)
       where t4.lkp_typ_lmpfp = 'MAX_TON_DAY'
         and t4.val_att3_lmpfp = p_cod_run
         and t4.val_att1_lmpfp = og.station_id
         and t4.val_att4_lmpfp = og.cod_ord_group
         and to_char(t4.dat_att_lmpfp, 'YYYYMM') = lv_month_cur;
    
    --commented at 13990615
      begin
        select nvl(t.qty_avg_invog, 0)
          into lv_min_inv
          from lmp.lmp_cap_inv_og_targets t
         where t.cod_order_group_invog = og.cod_ord_group
           and t.statn_bas_station_id = og.station_id;
        select nvl(round(sum(im.mu_wei) / 1000), 0)
          into lv_first_inv
          from mas_lmp_initial_mu_viw im, lmp.lmp_bas_orders o
         where im.station_id = og.station_id
           and o.cod_run_lmpor = p_cod_run
           and o.flg_active_in_model_lmpor = 1
              --and im.cod_run_capin = p_cod_run
           and o.cod_order_lmpor = im.cod_ord_ordhe
           and o.num_order_lmpor = im.num_item_ordit
           and LMP_RET_ORD_GROUP_FOR_ORD_FUN(p_cod_order => o.cod_order_lmpor ||
                                                            lpad(o.num_order_lmpor,
                                                                 3,
                                                                 '0')) =
               og.cod_ord_group;
        lv_min_inv := greatest(lv_min_inv - lv_first_inv, 0);
        --if lv_num_day < 10 then
        lv_min_inv := lv_min_inv / lv_num_day;
        --end if;
      exception
        when no_data_found then
          lv_min_inv := 0;
      end;
    
      update lmp.lmp_bas_fix_params t4
         set t4.val_att2_lmpfp = round((lv_rem_tot + lv_min_inv) * 1.1)
       where t4.lkp_typ_lmpfp = 'MAX_TON_DAY'
         and t4.val_att3_lmpfp = p_cod_run
         and t4.val_att1_lmpfp = 41
         and t4.val_att4_lmpfp = og.cod_ord_group
         and to_char(t4.dat_att_lmpfp, 'YYYYMM') = lv_month_cur;
    -- Commented at 13990615
    end loop; */
  
    select min(c.v_Dat_Calde_In_6)
      into lv_month_next
      from aac_lmp_calendar_viw c
     where c.v_Dat_Calde_In_6 > lv_month_cur;
  
    for i in (select ts.qty_plan_lstst,
                     ts.qty_max_lstst,
                     ts.qty_min_lstst,
                     ts.statn_bas_station_id,
                     pa.area_id,
                     pa.arstu_ide_pk_arstu
                from lmp.lmp_sop_target_stations ts,
                     lmp.lmp_bas_stations        st,
                     pms.pms_areas               pa
               where ts.cod_run_cap_lstst = '0'
                 and pa.area_id = st.area_area_id
                 and st.bas_station_id = ts.statn_bas_station_id
                 and ts.lkp_type_lstst = 'CAP_TARGET_STATION'
                 and ts.val_month_lstst = lv_month_next
                 and (ts.qty_plan_lstst > 0 or ts.qty_max_lstst > 0 or
                     ts.qty_min_lstst > 0)) loop
      /* begin
        select nvl(ts.qty_plan_lstst, 0)
          into lv_plan
          from lmp.lmp_sop_target_stations ts
         where ts.cod_run_cap_lstst = '0'
           and ts.lkp_type_lstst = 'CAP_TARGET_STATION'
           and ts.statn_bas_station_id = i.statn_bas_station_id
           and ts.val_month_lstst = lv_month_next;
      exception
        when no_data_found then
          lv_plan := 0;
      end;*/
      /* ------added by s.bousaiedi 13980829 for test must be deleted
      if i.statn_bas_station_id = 41 then
        select nvl(round(sum(t1.WEI_ASSIGNED_KG) / 1000), 0)
          into lv_plan_sch
          from apps.mas_lmp_assigned_slab_typ_viw t1
         where t1.NUM_AREA_ID_LOC_AASTH in (161, 160, 162, 163, 7375133);
      else
        lv_plan_sch := 0;
      end if;
      -------------------*/
    
      insert into LMP.LMP_CAP_DBD_INPUTS
        (CAP_DBD_INPUT_ID,
         STATN_BAS_STATION_ID,
         VAL_MONTH_DBDIN,
         LKP_TYP_DBDIN,
         QTY_PLAN_DBDIN,
         COD_RUN_DBDIN,
         QTY_MAX_DBDIN,
         QTY_MIN_DBDIN)
      values
        (lmp.lmp_cap_dbd_inputs_seq.nextval,
         i.statn_bas_station_id,
         lv_month_next,
         'TOTAL_STATION',
         (i.qty_plan_lstst /*- lv_plan_sch*/
         ) * ((select count(c.Dat_Calde)
                 from aac_lmp_calendar_viw c
                where c.v_Dat_Calde_In_6 = lv_month_next
                  and c.Dat_Calde <= lv_dat_end) /
         (select count(c.Dat_Calde)
                 from aac_lmp_calendar_viw c
                where c.v_Dat_Calde_In_6 = lv_month_next)),
         p_cod_run,
         (i.qty_max_lstst /*- lv_plan_sch*/
         ) * ((select count(c.Dat_Calde)
                 from aac_lmp_calendar_viw c
                where c.v_Dat_Calde_In_6 = lv_month_next
                  and c.Dat_Calde <= lv_dat_end) /
         (select count(c.Dat_Calde)
                 from aac_lmp_calendar_viw c
                where c.v_Dat_Calde_In_6 = lv_month_next)),
         (i.qty_min_lstst /*- lv_plan_sch*/
         ) * ((select count(c.Dat_Calde)
                 from aac_lmp_calendar_viw c
                where c.v_Dat_Calde_In_6 = lv_month_next
                  and c.Dat_Calde <= lv_dat_end) /
         (select count(c.Dat_Calde)
                 from aac_lmp_calendar_viw c
                where c.v_Dat_Calde_In_6 = lv_month_next)));
    
    end loop;
  
    /*   for i in (select cdi.statn_bas_station_id,
           cdi.qty_plan_dbdin,
           cdi.cod_order_group_dbdin,
           cdi.QTY_MAX_DBDIN,
           cdi.QTY_MIN_DBDIN,
           pa.area_id,
           pa.arstu_ide_pk_arstu
      from LMP.LMP_CAP_DBD_INPUTS cdi,
           lmp_bas_stations       st,
           pms_areas              pa
     where cdi.lkp_typ_dbdin = 'TOTAL_STATION_OG'
       and cdi.val_month_dbdin = lv_month_next
       and pa.area_id = st.area_area_id
       and st.bas_station_id = cdi.statn_bas_station_id
       and cdi.cod_run_dbdin = '0'
    --and cdi.qty_plan_dbdin is not null
    ) loop*/
  
    ----updated by s.boosaiedi 1398/07/28
    for i in (select cdi.statn_bas_station_id,
                     cdi.qty_plan_lstst,
                     cdi.cod_order_group_lstst,
                     cdi.Qty_Max_Lstst,
                     cdi.Qty_Min_Lstst,
                     pa.area_id,
                     pa.arstu_ide_pk_arstu
                from LMP.Lmp_Sop_Target_Stations cdi,
                     lmp.lmp_bas_stations        st,
                     pms.pms_areas               pa
               where cdi.lkp_type_lstst = 'CAP_TARGET_OG'
                 and cdi.val_month_lstst = lv_month_next
                 and pa.area_id = st.area_area_id
                 and st.bas_station_id = cdi.statn_bas_station_id
                 and cdi.cod_run_cap_lstst = '0') loop
    
      ----updated by s.boosaiedi 1398/07/28
      /*begin
        select nvl(ts.qty_plan_lstst, 0)
          into lv_plan
          from lmp.lmp_sop_target_stations ts
         where ts.cod_run_cap_lstst = '0'
           and ts.lkp_type_lstst = 'CAP_TARGET_OG'
           and ts.statn_bas_station_id = i.statn_bas_station_id
           and ts.val_month_lstst = lv_month_next
           and ts.cod_order_group_lstst = i.cod_order_group_dbdin;
      
      exception
        when no_data_found then
          lv_plan := null;
        
      end;*/
      insert into LMP.LMP_CAP_DBD_INPUTS
        (CAP_DBD_INPUT_ID,
         STATN_BAS_STATION_ID,
         VAL_MONTH_DBDIN,
         LKP_TYP_DBDIN,
         QTY_PLAN_DBDIN,
         COD_RUN_DBDIN,
         QTY_MIN_DBDIN,
         QTY_Max_DBDIN,
         COD_ORDER_GROUP_DBDIN)
      values
        (lmp.lmp_cap_dbd_inputs_seq.nextval,
         i.statn_bas_station_id,
         lv_month_next,
         'TOTAL_STATION_OG',
         i.qty_plan_lstst *
         ((select count(c.Dat_Calde)
             from aac_lmp_calendar_viw c
            where c.v_Dat_Calde_In_6 = lv_month_next
              and c.Dat_Calde <= lv_dat_end) /
         (select count(c.Dat_Calde)
             from aac_lmp_calendar_viw c
            where c.v_Dat_Calde_In_6 = lv_month_next)),
         p_cod_run,
         i.qty_min_lstst,
         i.qty_max_lstst,
         i.cod_order_group_lstst);
    
    end loop;
    --app_lmp_sop_model_pkg.calculate_target_station_prc(p_cod_run => p_cod_run);
    ---target daily
    ---ccm
  
    for i in (select t.statn_bas_station_id,
                     t.val_month_dbdin,
                     t.qty_plan_dbdin,
                     t.qty_max_dbdin,
                     t.qty_min_dbdin
                from lmp.lmp_cap_dbd_inputs t
               where t.lkp_typ_dbdin = 'TOTAL_STATION'
                 and t.cod_run_dbdin = p_cod_run
                 and t.statn_bas_station_id in (41)
                 and (t.qty_plan_dbdin > 0 or t.qty_max_dbdin > 0 or
                     t.qty_min_dbdin > 0)) loop
    
      lv_dat_start_smc := apps.api_mas_lmp_pkg.get_max_dat_prog_smc_Fun(apps.api_mas_models_pkg.Get_Last_AAS_Cod_Run_Fun);
      -- lv_dat_start_smc:=least(lv_dat_start_smc,to_date('13980531','yyyymmdd','nls_calendar=persian'));--must be omitted after 13980530
    
      SELECT COUNT(1)
        INTO LV_COUNT
        FROM APPS.LMP_AAC_CALENDAR_VIW V
       WHERE V.V_DAT_CALDE_IN_6 = I.VAL_MONTH_DBDIN
         AND V.DAT_CALDE > lv_dat_start_smc;
    
      select GREATEST((8 * 24 * LV_COUNT) -
                      nvl(sum(nvl(fp.val_att7_lmpfp, 0) +
                              nvl(fp.val_att8_lmpfp, 0)),
                          0),
                      0)
        into LV_CAP_FURNACE
        from lmp.lmp_bas_fix_params fp
       where fp.lkp_typ_lmpfp = 'FURNACE_STOP'
         and TO_CHAR(fp.dat_att_lmpfp, 'YYYYMM', 'NLS_CALENDAR=PERSIAN') =
             I.VAL_MONTH_DBDIN
         AND TRUNC(fp.dat_att_lmpfp) > lv_dat_start_smc;
    
      select SUM(NVL(bc.qty_capacity_bacap, 0))
        into LV_CAP_CASTING
        from lmp.lmp_bas_capacities bc
       where bc.statn_bas_station_id = I.STATN_BAS_STATION_ID
         and bc.cod_run_bacap = p_cod_run
         and bc.dat_day_bacap in
             (select c1.Dat_Calde
                from APPS.LMP_aac_calendar_viw c1
               where c1.v_Dat_Calde_In_6 = I.VAL_MONTH_DBDIN
                 AND c1.DAT_CALDE > lv_dat_start_smc);
    
      LV_CAP_AVLBL_TOT := (5 * LV_CAP_CASTING) + LV_CAP_FURNACE;
    
      FOR D IN (SELECT V.DAT_CALDE
                  FROM APPS.LMP_AAC_CALENDAR_VIW V
                 WHERE V.V_DAT_CALDE_IN_6 = I.VAL_MONTH_DBDIN
                   AND V.DAT_CALDE > lv_dat_start_smc
                 ORDER BY 1) LOOP
      
        select (8 * 24) -
               (select (nvl(sum(nvl(fp.val_att7_lmpfp, 0) +
                                nvl(fp.val_att8_lmpfp, 0)),
                            0))
                  from lmp.lmp_bas_fix_params fp
                 where fp.lkp_typ_lmpfp = 'FURNACE_STOP'
                   and trunc(fp.dat_att_lmpfp) = trunc(v.DAT_CALDE))
          into LV_CAP_FURNACE
          from apps.lmp_aac_calendar_viw v
         where trunc(v.DAT_CALDE) = TRUNC(D.DAT_CALDE);
      
        /* select (8 * 24) - nvl(sum(nvl(fp.val_att7_lmpfp, 0) +
                                 nvl(fp.val_att8_lmpfp, 0)),
                             0)
         into LV_CAP_FURNACE
         from lmp.lmp_bas_fix_params fp
        where fp.lkp_typ_lmpfp = 'FURNACE_STOP'
          and TRUNC(fp.dat_att_lmpfp) = TRUNC(D.DAT_CALDE);*/
      
        select SUM(NVL(bc.qty_capacity_bacap, 0))
          into LV_CAP_CASTING
          from lmp.lmp_bas_capacities bc
         where bc.statn_bas_station_id = I.STATN_BAS_STATION_ID
           and bc.cod_run_bacap = p_cod_run
           and TRUNC(bc.dat_day_bacap) = TRUNC(D.DAT_CALDE);
      
        LV_FACTOR := ((5 * LV_CAP_CASTING) + LV_CAP_FURNACE) /
                     LV_CAP_AVLBL_TOT;
      
        insert into lmp.lmp_cap_dbd_inputs
          (cap_dbd_input_id,
           statn_bas_station_id,
           dat_day_dbdin,
           qty_plan_dbdin,
           qty_max_dbdin,
           lkp_typ_dbdin,
           cod_run_dbdin)
        VALUES
          (lmp.lmp_cap_dbd_inputs_seq.nextval,
           I.STATN_BAS_STATION_ID,
           D.DAT_CALDE,
           ROUND((ROUND(((i.qty_plan_dbdin * LV_FACTOR) / 50), 0) * 50), 0),
           ROUND((ROUND(((i.qty_plan_dbdin * LV_FACTOR) / 50), 0) * 50) * 1.05,
                 0),
           'TOTAL_STATION_DAY',
           P_cod_run);
      END LOOP;
    END LOOP;
  
    /*for i in (select t.statn_bas_station_id,
                     t.val_month_dbdin,
                     t.qty_plan_dbdin,
                     t.qty_max_dbdin,
                     t.qty_min_dbdin
                from lmp.lmp_cap_dbd_inputs t
               where t.lkp_typ_dbdin = 'TOTAL_STATION'
                 and t.cod_run_dbdin = p_cod_run
                 and t.statn_bas_station_id in (41)
                 and (t.qty_plan_dbdin > 0 or t.qty_max_dbdin > 0 or
                     t.qty_min_dbdin > 0)) loop
      select sum(least(bc.qty_capacity_bacap * lv_pdw_ccm,
                       bc2.qty_capacity_bacap))
        into lv_tot_cap
        from lmp.lmp_bas_capacities bc, lmp.lmp_bas_capacities bc2
       where bc.statn_bas_station_id = i.statn_bas_station_id
         and bc.cod_run_bacap = p_cod_run
         and bc2.cod_run_bacap = p_cod_run
         and bc2.dat_day_bacap = bc.dat_day_bacap
         and bc2.statn_bas_station_id is null
         and bc.dat_day_bacap in
             (select c1.Dat_Calde
                from aac_lmp_calendar_viw c1
               where c1.v_Dat_Calde_In_6 = i.val_month_dbdin);
      if lv_tot_cap <= 0 then
        continue;
      end if;
      insert into lmp.lmp_cap_dbd_inputs
        (cap_dbd_input_id,
         statn_bas_station_id,
         dat_day_dbdin,
         qty_plan_dbdin,
         qty_max_dbdin,
         lkp_typ_dbdin,
         cod_run_dbdin)
        select lmp.lmp_cap_dbd_inputs_seq.nextval,
               bc1.statn_bas_station_id,
               bc1.dat_day_bacap,
               round((least(bc1.qty_capacity_bacap * lv_pdw_ccm,
                            bc3.qty_capacity_bacap) / lv_tot_cap) *
                     i.qty_plan_dbdin),
               round((least(bc1.qty_capacity_bacap * lv_pdw_ccm,
                            bc3.qty_capacity_bacap) / lv_tot_cap) *
                     i.qty_max_dbdin * 1.05),
               'TOTAL_STATION_DAY',
               P_cod_run
          from lmp.lmp_bas_capacities bc1, lmp.lmp_bas_capacities bc3
         where bc1.statn_bas_station_id = i.statn_bas_station_id
           and bc3.statn_bas_station_id is null
           and bc1.cod_run_bacap = p_cod_run
           and bc3.cod_run_bacap = p_cod_run
           and bc3.dat_day_bacap = bc1.dat_day_bacap
           and bc1.dat_day_bacap in
               (select c1.Dat_Calde
                  from aac_lmp_calendar_viw c1
                 where c1.v_Dat_Calde_In_6 = i.val_month_dbdin);
    end loop;*/
    ---end ccm
  
    ----hsm
    ----commented at 13980822 test
    /*for i in (select t.statn_bas_station_id,
                     t.val_month_dbdin,
                     t.qty_plan_dbdin,
                     t.qty_max_dbdin,
                     t.qty_min_dbdin
                from lmp.lmp_cap_dbd_inputs t
               where t.lkp_typ_dbdin = 'TOTAL_STATION'
                 and t.cod_run_dbdin = p_cod_run
                 and t.statn_bas_station_id = 45
                 and (t.qty_plan_dbdin > 0 or t.qty_max_dbdin > 0 or
                     t.qty_min_dbdin > 0)) loop
      select sum(bc.qty_capacity_bacap)
        into lv_tot_cap
        from lmp.lmp_bas_capacities bc
       where bc.statn_bas_station_id = i.statn_bas_station_id
         and bc.cod_run_bacap = p_cod_run
         and bc.dat_day_bacap in
             (select c1.Dat_Calde
                from aac_lmp_calendar_viw c1
               where c1.v_Dat_Calde_In_6 = i.val_month_dbdin);
      if lv_tot_cap <= 0 then
        continue;
      end if;
      select nvl(st.qty_prod_cost_statn, 100)
        into lv_round_base
        from lmp.lmp_bas_stations st
       where st.bas_station_id = i.statn_bas_station_id;
      insert into lmp.lmp_cap_dbd_inputs
        (cap_dbd_input_id,
         statn_bas_station_id,
         dat_day_dbdin,
         qty_plan_dbdin,
         qty_max_dbdin,
         lkp_typ_dbdin,
         cod_run_dbdin)
        select lmp.lmp_cap_dbd_inputs_seq.nextval,
               bc1.statn_bas_station_id,
               bc1.dat_day_bacap,
               round(((bc1.qty_capacity_bacap / lv_tot_cap) *
                     i.qty_plan_dbdin) / lv_round_base) * lv_round_base,
               round(((bc1.qty_capacity_bacap / lv_tot_cap) *
                     i.qty_max_dbdin * 1.05) / lv_round_base) *
               lv_round_base,
               'TOTAL_STATION_DAY',
               P_cod_run
          from lmp.lmp_bas_capacities bc1
         where bc1.statn_bas_station_id = i.statn_bas_station_id
           and bc1.cod_run_bacap = p_cod_run
           and bc1.dat_day_bacap in
               (select c1.Dat_Calde
                  from aac_lmp_calendar_viw c1
                 where c1.v_Dat_Calde_In_6 = i.val_month_dbdin);
    end loop;*/
    ---end hsm
  
    for i in (select t.statn_bas_station_id,
                     t.val_month_dbdin,
                     t.qty_plan_dbdin,
                     t.qty_max_dbdin,
                     t.qty_min_dbdin
                from lmp.lmp_cap_dbd_inputs t
               where t.lkp_typ_dbdin = 'TOTAL_STATION'
                 and t.cod_run_dbdin = p_cod_run
                 and t.statn_bas_station_id in (45) --, 74, 77, 78, 83, 79, 84,85,86,87,67,68,81,82)
                 and (t.qty_plan_dbdin > 0 or t.qty_max_dbdin > 0 or
                     t.qty_min_dbdin > 0)) loop
      select sum(bc.qty_capacity_bacap)
        into lv_tot_cap
        from lmp.lmp_bas_capacities bc
       where bc.statn_bas_station_id = i.statn_bas_station_id
         and bc.cod_run_bacap = p_cod_run
         and bc.dat_day_bacap in
             (select c1.Dat_Calde
                from aac_lmp_calendar_viw c1
               where c1.v_Dat_Calde_In_6 = i.val_month_dbdin);
      if lv_tot_cap <= 0 then
        continue;
      end if;
      /* select nvl(st.qty_prod_cost_statn, 100)
       into lv_round_base
       from lmp.lmp_bas_stations st
      where st.bas_station_id = i.statn_bas_station_id;*/
      lv_round_base := 1;
      insert into lmp.lmp_cap_dbd_inputs
        (cap_dbd_input_id,
         statn_bas_station_id,
         dat_day_dbdin,
         qty_plan_dbdin,
         qty_max_dbdin,
         lkp_typ_dbdin,
         cod_run_dbdin)
        select lmp.lmp_cap_dbd_inputs_seq.nextval,
               bc1.statn_bas_station_id,
               bc1.dat_day_bacap,
               round(((bc1.qty_capacity_bacap / lv_tot_cap) *
                     i.qty_plan_dbdin) / lv_round_base) * lv_round_base,
               round(((bc1.qty_capacity_bacap / lv_tot_cap) *
                     i.qty_max_dbdin * 1.05) / lv_round_base) *
               lv_round_base,
               'TOTAL_STATION_DAY',
               P_cod_run
          from lmp.lmp_bas_capacities bc1
         where bc1.statn_bas_station_id = i.statn_bas_station_id
           and bc1.cod_run_bacap = p_cod_run
           and bc1.dat_day_bacap in
               (select c1.Dat_Calde
                  from aac_lmp_calendar_viw c1
                 where c1.v_Dat_Calde_In_6 = i.val_month_dbdin);
    end loop;
  
    ------crm stations 
    for i in (select t.statn_bas_station_id,
                     t.val_month_dbdin,
                     t.qty_plan_dbdin,
                     t.qty_max_dbdin,
                     t.qty_min_dbdin
                from lmp.lmp_cap_dbd_inputs t
               where t.lkp_typ_dbdin = 'TOTAL_STATION'
                 and t.cod_run_dbdin = p_cod_run
                 and t.statn_bas_station_id in
                     (select st.bas_station_id
                        from lmp.lmp_bas_stations st, pms.pms_areas pa
                       where pa.area_id = st.area_area_id
                         and (pa.arstu_ide_pk_arstu like
                             'M.S.C CO/M.S.C/CCM%'))
                 and (t.qty_plan_dbdin > 0 or t.qty_max_dbdin > 0 or
                     t.qty_min_dbdin > 0)) loop
      select sum(bc.qty_capacity_bacap)
        into lv_tot_cap
        from lmp.lmp_bas_capacities bc
       where bc.statn_bas_station_id = i.statn_bas_station_id
         and bc.cod_run_bacap = p_cod_run
         and bc.dat_day_bacap in
             (select c1.Dat_Calde
                from aac_lmp_calendar_viw c1
               where c1.v_Dat_Calde_In_6 = i.val_month_dbdin);
      if lv_tot_cap <= 0 then
        continue;
      end if;
    
      select nvl(st.qty_prod_cost_statn, 100)
        into lv_round_base
        from lmp.lmp_bas_stations st
       where st.bas_station_id = i.statn_bas_station_id;
    
      lv_round_base := 1;
    
      insert into lmp.lmp_cap_dbd_inputs
        (cap_dbd_input_id,
         statn_bas_station_id,
         dat_day_dbdin,
         qty_plan_dbdin,
         qty_max_dbdin,
         lkp_typ_dbdin,
         cod_run_dbdin)
        select lmp.lmp_cap_dbd_inputs_seq.nextval,
               bc1.statn_bas_station_id,
               bc1.dat_day_bacap,
               round(((bc1.qty_capacity_bacap / lv_tot_cap) *
                     i.qty_plan_dbdin) / lv_round_base) * lv_round_base,
               round(((bc1.qty_capacity_bacap / lv_tot_cap) *
                     i.qty_max_dbdin * 1.05) / lv_round_base) *
               lv_round_base,
               'TOTAL_STATION_DAY',
               P_cod_run
          from lmp.lmp_bas_capacities bc1
         where bc1.statn_bas_station_id = i.statn_bas_station_id
           and bc1.cod_run_bacap = p_cod_run
           and bc1.dat_day_bacap in
               (select c1.Dat_Calde
                  from aac_lmp_calendar_viw c1
                 where c1.v_Dat_Calde_In_6 = i.val_month_dbdin);
    end loop;
    ------------end target daily
  
    update lmp_bas_model_run_stats m
       set m.dat_end_mosta  = sysdate,
           m.sta_step_mosta = 'پايان موفق'
     where m.cod_run_mosta = p_cod_run
       and m.num_step_mosta = 1
       and m.num_module_mosta = lv_module;
  
    app_lmp_cap_tot_model_pkg.update_model_stat_step_prc(p_cod_run     => lv_cod_run_tot,
                                                         p_cod_mjl_run => p_cod_run,
                                                         p_num_step    => 1,
                                                         P_NUM_MODULE  => lv_module,
                                                         p_flg_stat    => 1);
    commit;
    /*exception
    when others then
      \* select fp.val_att3_lmpfp
       into lv_msg2
       from lmp.lmp_bas_fix_params fp
      where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
        and fp.val_att1_lmpfp = 4;*\
    
      update lmp_bas_model_run_stats m
         set m.dat_end_mosta  = sysdate,
             m.sta_step_mosta = 'IC?C? I?C'
       where m.cod_run_mosta = p_cod_run
         and m.num_step_mosta = 1
         and m.num_module_mosta = 3;
      commit;*/
  end;
  ------------------------------------------------------------------------------
  procedure insert_capacity_plan_prc(p_cod_run       in varchar2,
                                     p_station_id    in number,
                                     p_pcn_cap       in number,
                                     p_qty_avail_cap in number,
                                     P_qty_avlbl_inv in number,
                                     p_qty_used_cap  in number,
                                     p_qty_used_inv  in number,
                                     p_qty_used_ton  in number,
                                     p_val_period    in varchar2) is
  begin
    --execute immediate 'alter session set nls_calendar=''persian''';
    insert into lmp_bas_capacity_plans
      (bas_capacity_plan_id,
       cod_run_cappl,
       cod_station_cappl,
       num_module_cappl,
       pcn_cap_cappl,
       qty_avlbl_cap_cappl,
       qty_avlbl_inv_cappl,
       qty_used_cap_cappl,
       qty_used_inv_cappl,
       qty_used_ton_cappl,
       DAT_DAY_CAPPL)
    values
      (lmp_bas_capacity_plans_seq.nextval,
       p_cod_run,
       p_station_id,
       3,
       p_pcn_cap,
       p_qty_avail_cap,
       P_qty_avlbl_inv,
       p_qty_used_cap,
       p_qty_used_inv,
       p_qty_used_ton,
       to_date(p_val_period, 'YYYYMMDD', 'nls_calendar=persian'));
  end;
  ----------------------------------------------------------
  procedure insert_model_stat_prc(p_cod_run    in varchar2,
                                  p_num_module in number,
                                  p_num_step   in number) is
    lv_msg1 varchar2(500);
    lv_msg2 varchar2(500);
  begin
  
    select fp.val_att3_lmpfp
      into lv_msg1
      from lmp.lmp_bas_fix_params fp
     where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
       and fp.val_att2_lmpfp = p_num_step;
    select fp.val_att3_lmpfp
      into lv_msg2
      from lmp.lmp_bas_fix_params fp
     where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
       and fp.val_att1_lmpfp = 2;
  
    insert into lmp_bas_model_run_stats
      (bas_model_run_stat_id,
       cod_run_mosta,
       num_step_mosta,
       des_step_mosta,
       sta_step_mosta,
       dat_start_mosta,
       num_module_mosta)
    values
      (lmp_bas_model_run_stats_seq.nextval,
       p_cod_run,
       p_num_step,
       lv_msg1,
       lv_msg2,
       sysdate,
       p_num_module);
  
    if p_num_module = 3 then
      update lmp.lmp_bas_run_histories rh
         set rh.des_status_rnhis = 'RUNNING STEP ' || p_num_step
       where rh.cod_run_rnhis = p_cod_run
         and rh.num_module_rnhis = p_num_module;
    end if;
  end;
  ---------------------------------------------------------------------
  procedure update_model_stat_prc(p_cod_run    in varchar2,
                                  p_num_module in number,
                                  p_num_step   in number,
                                  p_flg_ok     in number,
                                  p_des_error  in varchar2) is
    lv_msg2 varchar2(500);
    lv_msg1 varchar2(500);
    lv_user varchar2(500);
  begin
    if p_flg_ok = 1 then
      select fp.val_att3_lmpfp
        into lv_msg2
        from lmp.lmp_bas_fix_params fp
       where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
         and fp.val_att1_lmpfp = 3;
    else
      select fp.val_att3_lmpfp
        into lv_msg2
        from lmp.lmp_bas_fix_params fp
       where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
         and fp.val_att1_lmpfp = 4;
    end if;
  
    if (p_num_module IS NULL AND p_flg_ok = 0) then
      select fp.val_att3_lmpfp
        into lv_msg2
        from lmp.lmp_bas_fix_params fp
       where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
         and fp.val_att1_lmpfp = 2;
    
      update lmp_bas_model_run_stats t
         set t.dat_start_mosta = sysdate,
             t.sta_step_mosta  = lv_msg2,
             t.des_error_mosta = p_des_error
       where t.cod_run_mosta = p_cod_run
         and t.num_step_mosta = p_num_step
         and (t.num_module_mosta = p_num_module or
             t.num_module_mosta is null);
    ELSE
      update lmp_bas_model_run_stats t
         set t.dat_end_mosta   = sysdate,
             t.sta_step_mosta  = lv_msg2,
             t.des_error_mosta = p_des_error
       where t.cod_run_mosta = p_cod_run
         and t.num_step_mosta = p_num_step
         and (t.num_module_mosta = p_num_module or
             t.num_module_mosta is null);
    END IF;
  
    if p_num_module = 3 then
      begin
        if p_num_step = 4 then
          select fp.val_att3_lmpfp
            into lv_msg1
            from lmp.lmp_bas_fix_params fp
           where fp.lkp_typ_lmpfp = 'SMS_TEXT'
             and fp.val_att1_lmpfp = 2;
          select fp.val_att3_lmpfp
            into lv_msg2
            from lmp.lmp_bas_fix_params fp
           where fp.lkp_typ_lmpfp = 'SMS_TEXT'
             and fp.val_att1_lmpfp = 3;
        
          select sys_context('userenv', 'client_identifier')
            into lv_user
            from dual;
        
          lv_msg1 := lv_msg1 || p_cod_run || lv_msg2;
          --lv_msg1 := lv_msg1 || ' ?کاربر اجرا کننده: ' || lv_user;
          lv_msg2 := Fnd.Fnd_Sms_And_Email_Pkg.Send_Non_Adv_Sms_Fun(p_Recipientnumbers => sys.odcivarchar2list('09131657097',
                                                                                                               '09131275584',
                                                                                                               '09130197615',
                                                                                                               '09359721908'),
                                                                    p_Messagebodies    => lv_msg1);
        
        end if;
      exception
        when others then
          null;
      end;
    end if;
  end;
  ------------------------------------------------------
  procedure fill_inventories_prc is
    lv_string varchar2(1000);
    lv_num    number := 1;
    lv_msg    varchar2(1000);
  begin
    --lv_num := api_mas_pkg.Run_AAS_Assignment_Slt_Fun;
    if lv_num = 0 then
      app_lmp_global_pkg.insert_log_prc(p_fun_nam   => 'api_mas_pkg.Run_AAS_Assignment_Slt_Fun',
                                        p_inputs    => to_char(sysdate,
                                                               'YYYYMMDD'),
                                        p_outputs   => to_char(sysdate,
                                                               'YYYYMMDD'),
                                        p_flg_ok    => 0,
                                        p_des_error => 'In Assignmnt Model');
      return;
    end if;
    --lv_string := MAS_DB_FUNCS_PKG.Fill_General_Snapshot_Fun('LMP', 1);
  
    app_lmp_global_pkg.insert_log_prc(p_fun_nam   => 'api_mas_pkg.Run_AAS_Assignment_Slt_Fun',
                                      p_inputs    => '',
                                      p_outputs   => to_char(lv_num),
                                      p_flg_ok    => 1,
                                      p_des_error => lv_string);
    begin
      --app_smp_order_slab_assign_pkg.run_final_AUTOMATIC_ASSIGN_PRC(lp_DESERROR => lv_string);
      --app_smp_order_slab_assign_pkg.RET_NEED_DEMAND_ORDERS_PRC(lp_ord_num  => null,
      --                                                        lp_DESERROR => lv_string);
      null;
    exception
      when others then
        app_lmp_global_pkg.insert_log_prc(p_fun_nam   => 'SLAB_ASSIGNMENT',
                                          p_inputs    => to_char(sysdate,
                                                                 'YYYYMMDD'),
                                          p_outputs   => to_char(sysdate,
                                                                 'YYYYMMDD'),
                                          p_flg_ok    => 0,
                                          p_des_error => 'In SMP Assignmnt Model');
    end;
    begin
      lv_msg := Fnd.Fnd_Sms_And_Email_Pkg.Send_Non_Adv_Sms_Fun(sys.odciVarchar2List('09131657097',
                                                                                    '09131275584'),
                                                               p_Messagebodies => 'Assignment is ended:' ||
                                                                                  to_char(sysdate,
                                                                                          'MM/DD HH24:MI'));
    exception
      when others then
        null;
    end;
    app_lmp_global_pkg.insert_log_prc(p_fun_nam   => 'MAS_MODEL_START',
                                      p_inputs    => '',
                                      p_outputs   => 'DONE',
                                      p_flg_ok    => 1,
                                      p_des_error => null);
    commit;
    api_mas_models_pkg.Run_OFO_Pre_Cap_Model_Prc;
    app_lmp_global_pkg.insert_log_prc(p_fun_nam   => 'MAS_MODEL_END',
                                      p_inputs    => '',
                                      p_outputs   => 'DONE',
                                      p_flg_ok    => 1,
                                      p_des_error => null);
    commit;
    app_lmp_sop_model_pkg.create_order_info_tot_prc;
    app_lmp_sop_model_pkg.create_virtual_order_prc;
    app_lmp_global_pkg.insert_log_prc(p_fun_nam   => 'End_Create_Order',
                                      p_inputs    => '',
                                      p_outputs   => to_char(sysdate,
                                                             'YYYYMMDD'),
                                      p_flg_ok    => 1,
                                      p_des_error => null);
    --create virtual orders
    commit;
    --lv_num := smp_its_send_orders_fun;
    --commit;
  end;
  -------------------------------------------------------
  procedure fill_earli_tardi_order_prc(p_cod_run in varchar2) is
    lv_st_month  varchar2(6);
    lv_end_month varchar2(6);
    lv_tot_ton   number;
    lv_prod_ton  number;
    lv_cur_week  varchar2(6);
    lv_dat_st    date;
  begin
    select to_char(t.dat_strt_hrzn_rnhis, 'YYYYMM'),
           to_char(t.dat_end_hrzn_rnhis, 'YYYYMM'),
           t.dat_strt_hrzn_rnhis
      into lv_st_month, lv_end_month, lv_dat_st
      from lmp_bas_run_histories t
     where t.cod_run_rnhis = p_cod_run
       and t.num_module_rnhis = 3;
    --before start month
    select sum(o.qty_demand_lmpor) / 1000
      into lv_tot_ton
      from lmp.lmp_bas_orders o
     where o.cod_run_lmpor = p_cod_run
       and to_char(o.dat_dlv_lmpor, 'YYYYMM') < lv_st_month;
    insert into lmp.lmp_bas_fix_params
      (bas_fix_param_id,
       val_att1_lmpfp,
       val_att4_lmpfp,
       val_att3_lmpfp,
       lkp_typ_lmpfp,
       val_att5_lmpfp,
       val_att7_lmpfp)
    values
      (lmp.lmp_bas_fix_params_seq.nextval,
       1,
       p_cod_run,
       'before ' || lv_st_month,
       'CAP_TEST_ET',
       'on dlv Week',
       0);
    insert into lmp.lmp_bas_fix_params
      (bas_fix_param_id,
       val_att1_lmpfp,
       val_att4_lmpfp,
       val_att3_lmpfp,
       lkp_typ_lmpfp,
       val_att5_lmpfp,
       val_att7_lmpfp)
    values
      (lmp.lmp_bas_fix_params_seq.nextval,
       2,
       p_cod_run,
       'before ' || lv_st_month,
       'CAP_TEST_ET',
       '1 Week before',
       0);
  
    select c.Num_Week_Year_Ppc_Calde
      into lv_cur_week
      from aac_lmp_calendar_viw c
     where c.Dat_Calde = lv_dat_st;
  
    select nvl(sum(sp.qty_sale_salpl), 0)
      into lv_prod_ton
      from lmp_sop_sale_plans sp
     where sp.cod_run_salpl = p_cod_run
       and sp.dat_day_salpl in
           (select c.Dat_Calde
              from aac_lmp_calendar_viw c
             where c.Num_Week_Year_Ppc_Calde = lv_cur_week)
       and (sp.cod_order_salpl, sp.num_item_salpl) in
           (select o.cod_order_lmpor, o.num_order_lmpor
              from lmp_bas_orders o
             where o.cod_run_lmpor = p_cod_run
               and to_char(o.dat_dlv_lmpor, 'YYYYMM') < lv_st_month);
  
    insert into lmp.lmp_bas_fix_params
      (bas_fix_param_id,
       val_att1_lmpfp,
       val_att4_lmpfp,
       val_att3_lmpfp,
       lkp_typ_lmpfp,
       val_att5_lmpfp,
       val_att7_lmpfp)
    values
      (lmp.lmp_bas_fix_params_seq.nextval,
       3,
       p_cod_run,
       'before ' || lv_st_month,
       'CAP_TEST_ET',
       '1 Week later',
       round((lv_prod_ton / lv_tot_ton) * 100, 1));
  
    insert into lmp.lmp_bas_fix_params
      (bas_fix_param_id,
       val_att1_lmpfp,
       val_att4_lmpfp,
       val_att3_lmpfp,
       lkp_typ_lmpfp,
       val_att5_lmpfp,
       val_att7_lmpfp)
    values
      (lmp.lmp_bas_fix_params_seq.nextval,
       4,
       p_cod_run,
       'before ' || lv_st_month,
       'CAP_TEST_ET',
       '2 Weeks before',
       0);
  
    select nvl(sum(sp.qty_sale_salpl), 0)
      into lv_prod_ton
      from lmp_sop_sale_plans sp
     where sp.cod_run_salpl = p_cod_run
       and sp.dat_day_salpl in
           (select c.Dat_Calde
              from aac_lmp_calendar_viw c
             where c.Num_Week_Year_Ppc_Calde = lv_cur_week + 1)
       and (sp.cod_order_salpl, sp.num_item_salpl) in
           (select o.cod_order_lmpor, o.num_order_lmpor
              from lmp_bas_orders o
             where o.cod_run_lmpor = p_cod_run
               and to_char(o.dat_dlv_lmpor, 'YYYYMM') < lv_st_month);
  
    insert into lmp.lmp_bas_fix_params
      (bas_fix_param_id,
       val_att1_lmpfp,
       val_att4_lmpfp,
       val_att3_lmpfp,
       lkp_typ_lmpfp,
       val_att5_lmpfp,
       val_att7_lmpfp)
    values
      (lmp.lmp_bas_fix_params_seq.nextval,
       5,
       p_cod_run,
       'before ' || lv_st_month,
       'CAP_TEST_ET',
       '2 Weeks later',
       round((lv_prod_ton / lv_tot_ton) * 100, 1));
    insert into lmp.lmp_bas_fix_params
      (bas_fix_param_id,
       val_att1_lmpfp,
       val_att4_lmpfp,
       val_att3_lmpfp,
       lkp_typ_lmpfp,
       val_att5_lmpfp,
       val_att7_lmpfp)
    values
      (lmp.lmp_bas_fix_params_seq.nextval,
       4,
       p_cod_run,
       'before ' || lv_st_month,
       'CAP_TEST_ET',
       'more than 2 Weeks before',
       0);
  
    select nvl(sum(sp.qty_sale_salpl), 0)
      into lv_prod_ton
      from lmp_sop_sale_plans sp
     where sp.cod_run_salpl = p_cod_run
       and sp.dat_day_salpl in
           (select c.Dat_Calde
              from aac_lmp_calendar_viw c
             where c.Num_Week_Year_Ppc_Calde > lv_cur_week + 1)
       and (sp.cod_order_salpl, sp.num_item_salpl) in
           (select o.cod_order_lmpor, o.num_order_lmpor
              from lmp_bas_orders o
             where o.cod_run_lmpor = p_cod_run
               and to_char(o.dat_dlv_lmpor, 'YYYYMM') < lv_st_month);
  
    insert into lmp.lmp_bas_fix_params
      (bas_fix_param_id,
       val_att1_lmpfp,
       val_att4_lmpfp,
       val_att3_lmpfp,
       lkp_typ_lmpfp,
       val_att5_lmpfp,
       val_att7_lmpfp)
    values
      (lmp.lmp_bas_fix_params_seq.nextval,
       6,
       p_cod_run,
       'before ' || lv_st_month,
       'CAP_TEST_ET',
       'more than 2 Weeks later',
       round((lv_prod_ton / lv_tot_ton) * 100, 1));
  
    select nvl(sum(sp.qty_sale_salpl), 0)
      into lv_prod_ton
      from lmp_sop_sale_plans sp
     where sp.cod_run_salpl = p_cod_run
          /*and sp.dat_day_salpl in
          (select c.Dat_Calde
             from aac_lmp_calendar_viw c
            where c.Num_Week_Year_Ppc_Calde > lv_cur_week + 1)*/
       and (sp.cod_order_salpl, sp.num_item_salpl) in
           (select o.cod_order_lmpor, o.num_order_lmpor
              from lmp_bas_orders o
             where o.cod_run_lmpor = p_cod_run
               and to_char(o.dat_dlv_lmpor, 'YYYYMM') < lv_st_month);
  
    insert into lmp.lmp_bas_fix_params
      (bas_fix_param_id,
       val_att1_lmpfp,
       val_att4_lmpfp,
       val_att3_lmpfp,
       lkp_typ_lmpfp,
       val_att5_lmpfp,
       val_att7_lmpfp)
    values
      (lmp.lmp_bas_fix_params_seq.nextval,
       7,
       p_cod_run,
       'before ' || lv_st_month,
       'CAP_TEST_ET',
       'not delivered',
       round(((lv_tot_ton - lv_prod_ton) / lv_tot_ton) * 100, 1));
  
    insert into lmp.lmp_bas_fix_params
      (bas_fix_param_id,
       val_att1_lmpfp,
       val_att4_lmpfp,
       val_att3_lmpfp,
       lkp_typ_lmpfp,
       val_att5_lmpfp,
       val_att7_lmpfp)
    values
      (lmp.lmp_bas_fix_params_seq.nextval,
       8,
       p_cod_run,
       'before ' || lv_st_month,
       'CAP_TEST_ET',
       'Tot ton',
       lv_tot_ton);
  
    -----------------------
    for i in (select distinct cal.v_Dat_Calde_In_6
                from aac_lmp_calendar_viw cal
               where cal.v_Dat_Calde_In_6 between lv_st_month and
                     lv_end_month
               order by cal.v_Dat_Calde_In_6) loop
      select nvl(sum(o.qty_demand_lmpor), 0) / 1000
        into lv_tot_ton
        from lmp.lmp_bas_orders o
       where o.cod_run_lmpor = p_cod_run
         and to_char(o.dat_dlv_lmpor, 'YYYYMM') = i.v_dat_calde_in_6;
    
      select max(c.Num_Week_Year_Ppc_Calde)
        into lv_cur_week
        from aac_lmp_calendar_viw c
       where c.v_Dat_Calde_In_6 = i.v_dat_calde_in_6;
    
      select nvl(sum(sp.qty_sale_salpl), 0)
        into lv_prod_ton
        from lmp_sop_sale_plans sp, lmp_bas_orders o
       where sp.cod_run_salpl = p_cod_run
         and o.cod_run_lmpor = p_cod_run
         and sp.cod_order_salpl = o.cod_order_lmpor
         and sp.num_item_salpl = o.num_order_lmpor
         and to_char(o.dat_dlv_lmpor, 'YYYYMM') = i.v_dat_calde_in_6
         and (select c.Num_Week_Year_Ppc_Calde
                from aac_lmp_calendar_viw c
               where c.Dat_Calde = sp.dat_day_salpl) = o.val_week_lmpor;
    
      insert into lmp.lmp_bas_fix_params
        (bas_fix_param_id,
         val_att1_lmpfp,
         val_att4_lmpfp,
         val_att3_lmpfp,
         lkp_typ_lmpfp,
         val_att5_lmpfp,
         val_att7_lmpfp)
      values
        (lmp.lmp_bas_fix_params_seq.nextval,
         9,
         p_cod_run,
         i.v_dat_calde_in_6,
         'CAP_TEST_ET',
         'on dlv Week',
         round((lv_prod_ton / lv_tot_ton) * 100, 1));
    
      select nvl(sum(sp.qty_sale_salpl), 0)
        into lv_prod_ton
        from lmp_sop_sale_plans sp, lmp_bas_orders o
       where sp.cod_run_salpl = p_cod_run
         and o.cod_run_lmpor = p_cod_run
         and sp.cod_order_salpl = o.cod_order_lmpor
         and sp.num_item_salpl = o.num_order_lmpor
         and to_char(o.dat_dlv_lmpor, 'YYYYMM') = i.v_dat_calde_in_6
         and (select c.Num_Week_Year_Ppc_Calde
                from aac_lmp_calendar_viw c
               where c.Dat_Calde = sp.dat_day_salpl) = o.val_week_lmpor - 1;
    
      insert into lmp.lmp_bas_fix_params
        (bas_fix_param_id,
         val_att1_lmpfp,
         val_att4_lmpfp,
         val_att3_lmpfp,
         lkp_typ_lmpfp,
         val_att5_lmpfp,
         val_att7_lmpfp)
      values
        (lmp.lmp_bas_fix_params_seq.nextval,
         10,
         p_cod_run,
         i.v_dat_calde_in_6,
         'CAP_TEST_ET',
         '1 Week before',
         round((lv_prod_ton / lv_tot_ton) * 100, 1));
    
      select nvl(sum(sp.qty_sale_salpl), 0)
        into lv_prod_ton
        from lmp_sop_sale_plans sp, lmp_bas_orders o
       where sp.cod_run_salpl = p_cod_run
         and o.cod_run_lmpor = p_cod_run
         and sp.cod_order_salpl = o.cod_order_lmpor
         and sp.num_item_salpl = o.num_order_lmpor
         and to_char(o.dat_dlv_lmpor, 'YYYYMM') = i.v_dat_calde_in_6
         and (select c.Num_Week_Year_Ppc_Calde
                from aac_lmp_calendar_viw c
               where c.Dat_Calde = sp.dat_day_salpl) = o.val_week_lmpor + 1;
    
      insert into lmp.lmp_bas_fix_params
        (bas_fix_param_id,
         val_att1_lmpfp,
         val_att4_lmpfp,
         val_att3_lmpfp,
         lkp_typ_lmpfp,
         val_att5_lmpfp,
         val_att7_lmpfp)
      values
        (lmp.lmp_bas_fix_params_seq.nextval,
         11,
         p_cod_run,
         i.v_dat_calde_in_6,
         'CAP_TEST_ET',
         '1 Week later',
         round((lv_prod_ton / lv_tot_ton) * 100, 1));
    
      select nvl(sum(sp.qty_sale_salpl), 0)
        into lv_prod_ton
        from lmp_sop_sale_plans sp, lmp_bas_orders o
       where sp.cod_run_salpl = p_cod_run
         and o.cod_run_lmpor = p_cod_run
         and sp.cod_order_salpl = o.cod_order_lmpor
         and sp.num_item_salpl = o.num_order_lmpor
         and to_char(o.dat_dlv_lmpor, 'YYYYMM') = i.v_dat_calde_in_6
         and (select c.Num_Week_Year_Ppc_Calde
                from aac_lmp_calendar_viw c
               where c.Dat_Calde = sp.dat_day_salpl) = o.val_week_lmpor - 2;
    
      insert into lmp.lmp_bas_fix_params
        (bas_fix_param_id,
         val_att1_lmpfp,
         val_att4_lmpfp,
         val_att3_lmpfp,
         lkp_typ_lmpfp,
         val_att5_lmpfp,
         val_att7_lmpfp)
      values
        (lmp.lmp_bas_fix_params_seq.nextval,
         12,
         p_cod_run,
         i.v_dat_calde_in_6,
         'CAP_TEST_ET',
         '2 Weeks before',
         round((lv_prod_ton / lv_tot_ton) * 100, 1));
    
      select nvl(sum(sp.qty_sale_salpl), 0)
        into lv_prod_ton
        from lmp_sop_sale_plans sp, lmp_bas_orders o
       where sp.cod_run_salpl = p_cod_run
         and o.cod_run_lmpor = p_cod_run
         and sp.cod_order_salpl = o.cod_order_lmpor
         and sp.num_item_salpl = o.num_order_lmpor
         and to_char(o.dat_dlv_lmpor, 'YYYYMM') = i.v_dat_calde_in_6
         and (select c.Num_Week_Year_Ppc_Calde
                from aac_lmp_calendar_viw c
               where c.Dat_Calde = sp.dat_day_salpl) = o.val_week_lmpor + 2;
    
      insert into lmp.lmp_bas_fix_params
        (bas_fix_param_id,
         val_att1_lmpfp,
         val_att4_lmpfp,
         val_att3_lmpfp,
         lkp_typ_lmpfp,
         val_att5_lmpfp,
         val_att7_lmpfp)
      values
        (lmp.lmp_bas_fix_params_seq.nextval,
         13,
         p_cod_run,
         i.v_dat_calde_in_6,
         'CAP_TEST_ET',
         '2 Weeks later',
         round((lv_prod_ton / lv_tot_ton) * 100, 1));
    
      select nvl(sum(sp.qty_sale_salpl), 0)
        into lv_prod_ton
        from lmp_sop_sale_plans sp, lmp_bas_orders o
       where sp.cod_run_salpl = p_cod_run
         and o.cod_run_lmpor = p_cod_run
         and sp.cod_order_salpl = o.cod_order_lmpor
         and sp.num_item_salpl = o.num_order_lmpor
         and to_char(o.dat_dlv_lmpor, 'YYYYMM') = i.v_dat_calde_in_6
         and (select c.Num_Week_Year_Ppc_Calde
                from aac_lmp_calendar_viw c
               where c.Dat_Calde = sp.dat_day_salpl) < o.val_week_lmpor - 2;
    
      insert into lmp.lmp_bas_fix_params
        (bas_fix_param_id,
         val_att1_lmpfp,
         val_att4_lmpfp,
         val_att3_lmpfp,
         lkp_typ_lmpfp,
         val_att5_lmpfp,
         val_att7_lmpfp)
      values
        (lmp.lmp_bas_fix_params_seq.nextval,
         14,
         p_cod_run,
         i.v_dat_calde_in_6,
         'CAP_TEST_ET',
         'more than 2 Weeks before',
         round((lv_prod_ton / lv_tot_ton) * 100, 1));
    
      select nvl(sum(sp.qty_sale_salpl), 0)
        into lv_prod_ton
        from lmp_sop_sale_plans sp, lmp_bas_orders o
       where sp.cod_run_salpl = p_cod_run
         and o.cod_run_lmpor = p_cod_run
         and sp.cod_order_salpl = o.cod_order_lmpor
         and sp.num_item_salpl = o.num_order_lmpor
         and to_char(o.dat_dlv_lmpor, 'YYYYMM') = i.v_dat_calde_in_6
         and (select c.Num_Week_Year_Ppc_Calde
                from aac_lmp_calendar_viw c
               where c.Dat_Calde = sp.dat_day_salpl) > o.val_week_lmpor + 2;
    
      insert into lmp.lmp_bas_fix_params
        (bas_fix_param_id,
         val_att1_lmpfp,
         val_att4_lmpfp,
         val_att3_lmpfp,
         lkp_typ_lmpfp,
         val_att5_lmpfp,
         val_att7_lmpfp)
      values
        (lmp.lmp_bas_fix_params_seq.nextval,
         16,
         p_cod_run,
         i.v_dat_calde_in_6,
         'CAP_TEST_ET',
         'more than 2 Weeks later',
         round((lv_prod_ton / lv_tot_ton) * 100, 1));
    
      select nvl(sum(sp.qty_sale_salpl), 0)
        into lv_prod_ton
        from lmp_sop_sale_plans sp
       where sp.cod_run_salpl = p_cod_run
         and (sp.cod_order_salpl, sp.num_item_salpl) in
             (select o.cod_order_lmpor, o.num_order_lmpor
                from lmp_bas_orders o
               where o.cod_run_lmpor = p_cod_run
                 and to_char(o.dat_dlv_lmpor, 'YYYYMM') = i.v_dat_calde_in_6);
    
      insert into lmp.lmp_bas_fix_params
        (bas_fix_param_id,
         val_att1_lmpfp,
         val_att4_lmpfp,
         val_att3_lmpfp,
         lkp_typ_lmpfp,
         val_att5_lmpfp,
         val_att7_lmpfp)
      values
        (lmp.lmp_bas_fix_params_seq.nextval,
         17,
         p_cod_run,
         i.v_dat_calde_in_6,
         'CAP_TEST_ET',
         'not delivered',
         round(((lv_tot_ton - lv_prod_ton) / lv_tot_ton) * 100, 1));
    
      insert into lmp.lmp_bas_fix_params
        (bas_fix_param_id,
         val_att1_lmpfp,
         val_att4_lmpfp,
         val_att3_lmpfp,
         lkp_typ_lmpfp,
         val_att5_lmpfp,
         val_att7_lmpfp)
      values
        (lmp.lmp_bas_fix_params_seq.nextval,
         18,
         p_cod_run,
         i.v_dat_calde_in_6,
         'CAP_TEST_ET',
         'Tot ton',
         lv_tot_ton);
    end loop;
    --------------------------------
  end;
  -----------------------------------------------------
  procedure fill_prod_datlast_report_prc(p_cod_run in varchar2) is
    lv_start_dat    date;
    lv_end_dat      date;
    lv_start_week   varchar2(6);
    lv_end_week     varchar2(6);
    lv_qty_need     number;
    lv_delay        number;
    lv_early        number;
    lv_on_dlv       number;
    lv_qty_prod     number;
    lv_flg_first    number;
    lv_temp         number;
    lv_remain       number;
    lv_remain_prev  number;
    lv_prod_virtual number;
  begin
    execute immediate 'alter session set nls_calendar=''persian''';
  
    delete from lmp.lmp_cap_rel_reports rr
     where rr.cod_run_relre = p_cod_run;
    delete from lmp.lmp_cap_prod_reports pr
     where pr.cod_run_prrep = p_cod_run;
  
    select h.dat_strt_hrzn_rnhis, h.dat_end_hrzn_rnhis
      into lv_start_dat, lv_end_dat
      from lmp_bas_run_histories h
     where h.cod_run_rnhis = p_cod_run
       and h.num_module_rnhis = 3;
  
    select c.Num_Week_Year_Ppc_Calde
      into lv_start_week
      from aac_lmp_calendar_viw c
     where c.Dat_Calde = lv_start_dat;
    select c.Num_Week_Year_Ppc_Calde
      into lv_end_week
      from aac_lmp_calendar_viw c
     where c.Dat_Calde = lv_end_dat;
  
    for s in (select st.bas_station_id
                from lmp_bas_stations st
               where st.lkp_region_statn in ('SMC', 'HSM')) loop
      for og in (select distinct fp.val_att4_lmpfp
                   from lmp.lmp_bas_fix_params fp
                  where fp.lkp_typ_lmpfp = 'DAY_BY_DAY'
                    and fp.val_att4_lmpfp not in ('40', '92')
                  order by fp.val_att4_lmpfp
                 --and fp.val_att1_lmpfp = s.bas_station_id
                 ) loop
        lv_flg_first := 0;
        for w in (select Num_Week_Year_Ppc_Calde, min_dat, max_dat
                    from (select c.Num_Week_Year_Ppc_Calde,
                                 min(c.Dat_Calde) min_dat,
                                 max(c.Dat_Calde) max_dat
                            from aac_lmp_calendar_viw c
                           where c.Dat_Calde between lv_start_dat and
                                 lv_end_dat
                           group by c.Num_Week_Year_Ppc_Calde)
                   order by Num_Week_Year_Ppc_Calde) loop
        
          if lv_flg_first = 0 then
            select nvl(sum(nvl(t.qty_need_orfig, 0)), 0)
              into lv_qty_need
              from lmp.lmp_bas_order_configs t, lmp_bas_orders o
             where t.statn_bas_station_id = s.bas_station_id
               and o.cod_order_lmpor = t.cod_ord_header_orfig
               and o.num_order_lmpor = t.num_item_orfig
               and o.cod_run_lmpor = p_cod_run
               and o.flg_active_in_model_lmpor = 1
               and o.cod_order_group_lmpor = og.val_att4_lmpfp
               and t.cod_run_orfig = '00'
               and nvl(o.flg_virtual_lmpor, 0) <= 1
               and t.val_datlast_orfig <= w.num_week_year_ppc_calde;
            lv_qty_prod := 0;
            --lv_flg_first := 1;
            --lv_need_cum:=lv_qty_need;
          else
            select nvl(sum(nvl(t.qty_need_orfig, 0)), 0)
              into lv_qty_need
              from lmp.lmp_bas_order_configs t, lmp_bas_orders o
             where t.statn_bas_station_id = s.bas_station_id
               and o.cod_order_lmpor = t.cod_ord_header_orfig
               and o.num_order_lmpor = t.num_item_orfig
               and o.cod_run_lmpor = p_cod_run
               and o.cod_order_group_lmpor = og.val_att4_lmpfp
               and t.val_datlast_orfig = w.num_week_year_ppc_calde
               and t.cod_run_orfig = '00'
               and nvl(o.flg_virtual_lmpor, 0) <= 1
               and o.flg_active_in_model_lmpor = 1;
            --lv_qty_need := lv_qty_need - lv_qty_prod+nvl(lv_temp,0);
            select nvl(sum(nvl(rr.qty_prod_relre, 0)), 0)
              into lv_temp
              from lmp.Lmp_Cap_Rel_Reports rr
             where rr.cod_run_relre = p_cod_run
               and rr.cod_station_relre = s.bas_station_id
               and rr.cod_order_group_relre = og.val_att4_lmpfp
               and rr.val_rel_week_relre = w.num_week_year_ppc_calde
               and rr.val_week_relre < w.num_week_year_ppc_calde;
            lv_qty_need := lv_qty_need - nvl(lv_temp, 0);
            lv_qty_prod := 0;
            --lv_need_cum:=lv_need_cum+lv_qty_need;
          end if;
          lv_delay  := 0;
          lv_early  := 0;
          lv_on_dlv := 0;
        
          for i in (select nvl(sum(po.qty_prod_ppord), 0) as qty_prod_ppord,
                           oc.val_datlast_orfig,
                           o.cod_order_group_lmpor
                      from lmp_sop_prod_plan_orders  po,
                           lmp.lmp_bas_order_configs oc,
                           lmp_bas_orders            o
                     where po.cod_run_ppord = p_cod_run
                       and po.cod_station_ppord = s.bas_station_id
                       and oc.cod_ord_header_orfig = po.cod_order_ppord
                       and oc.num_item_orfig = po.num_item_ppord
                       and oc.statn_bas_station_id = s.bas_station_id
                       and o.cod_order_lmpor = oc.cod_ord_header_orfig
                       and oc.cod_run_orfig = '00'
                       and nvl(o.flg_virtual_lmpor, 0) <= 1
                       and o.num_order_lmpor = oc.num_item_orfig
                       and o.cod_run_lmpor = p_cod_run
                       and o.flg_active_in_model_lmpor = 1
                       and o.cod_order_group_lmpor = og.val_att4_lmpfp
                       and po.dat_day_ppord between w.min_dat and w.max_dat
                     group by oc.val_datlast_orfig, o.cod_order_group_lmpor) loop
            if i.val_datlast_orfig < w.num_week_year_ppc_calde then
              lv_delay := lv_delay + i.qty_prod_ppord;
            end if;
            if i.val_datlast_orfig = w.num_week_year_ppc_calde then
              lv_on_dlv := lv_on_dlv + i.qty_prod_ppord;
            end if;
            if i.val_datlast_orfig > w.num_week_year_ppc_calde or
               i.val_datlast_orfig is null then
              lv_early := lv_early + i.qty_prod_ppord;
            end if;
            lv_qty_prod := nvl(lv_qty_prod, 0) + nvl(i.qty_prod_ppord, 0);
            insert into global_temps
              (indx, att21, att1, att2, att3, att4, att22, att5)
            values
              (global_temp_seq.nextval,
               s.bas_station_id,
               p_cod_run,
               i.cod_order_group_lmpor,
               w.num_week_year_ppc_calde,
               i.val_datlast_orfig,
               i.qty_prod_ppord,
               'CAP');
          end loop;
        
          select sum(po.qty_prod_ppord)
            into lv_prod_virtual
            from lmp_sop_prod_plan_orders  po,
                 lmp.lmp_bas_order_configs oc,
                 lmp_bas_orders            o
           where po.cod_run_ppord = p_cod_run
             and po.cod_station_ppord = s.bas_station_id
             and oc.cod_ord_header_orfig = po.cod_order_ppord
             and oc.num_item_orfig = po.num_item_ppord
             and oc.statn_bas_station_id = s.bas_station_id
             and o.cod_order_lmpor = oc.cod_ord_header_orfig
             and oc.cod_run_orfig = '00'
             and nvl(o.flg_virtual_lmpor, 0) > 1
             and o.num_order_lmpor = oc.num_item_orfig
             and o.cod_run_lmpor = p_cod_run
             and o.flg_active_in_model_lmpor = 1
             and o.cod_order_group_lmpor = og.val_att4_lmpfp
             and po.dat_day_ppord between w.min_dat and w.max_dat;
        
          insert into lmp.lmp_cap_rel_reports
            (cap_rel_report_id,
             cod_station_relre,
             cod_run_relre,
             cod_order_group_relre,
             val_week_relre,
             val_rel_week_relre,
             qty_prod_relre)
            select lmp.lmp_cap_rel_reports_seq.nextval,
                   tt.cod_station,
                   p_cod_run,
                   tt.cod_og,
                   tt.val_week,
                   tt.val_rel_week,
                   tt.sum_ton
              from (select t.att21 as cod_station,
                           t.att2 as cod_og,
                           t.att3 as val_week,
                           t.att4 as val_rel_week,
                           sum(t.att22) as sum_ton
                      from global_temps t
                     where t.att5 = 'CAP'
                       and t.att1 = p_cod_run
                     group by t.att21, t.att2, t.att3, t.att4) tt;
          delete from global_temps gt where gt.att5 = 'CAP';
          --lv_remain := lv_qty_need - lv_delay + lv_on_dlv;
          if lv_flg_first = 0 then
            lv_remain_prev := lv_qty_need - lv_delay - lv_on_dlv;
            lv_remain      := lv_remain_prev;
            lv_flg_first   := 1;
          else
            lv_remain      := lv_remain_prev + lv_qty_need - lv_delay -
                              lv_on_dlv;
            lv_remain_prev := lv_remain;
          end if;
        
          insert into lmp.lmp_cap_prod_reports
            (cap_prod_report_id,
             cod_run_prrep,
             cod_station_prrep,
             val_week_prrep,
             cod_order_group_prrep,
             qty_delay_prod_prrep,
             qty_erli_prod_prrep,
             qty_need_prrep,
             qty_on_dlv_prod_prrep,
             qty_remain_prrep,
             QTY_SUM_PROD_PRREP,
             QTY_PROD_VIRTUAL_PRREP)
          values
            (lmp.lmp_cap_prod_reports_seq.nextval,
             p_cod_run,
             s.bas_station_id,
             w.num_week_year_ppc_calde,
             og.val_att4_lmpfp,
             lv_delay,
             lv_early,
             lv_qty_need,
             lv_on_dlv,
             lv_remain,
             lv_qty_prod + nvl(lv_prod_virtual, 0),
             lv_prod_virtual);
        end loop;
      end loop;
    end loop;
  
    --APP_LMP_CAP_TOT_MODEL_PKG.update_order_plan_prc(p_cod_run => p_cod_run);
  
  end;
  ---------------------------------------
  procedure fill_capacity_model_prc(p_cod_run   in varchar2,
                                    p_start_dat in date,
                                    p_end_dat   in date) is
    lv_arst    varchar2(500);
    lv_area_id number;
  
  begin
    null;
  end;
  -------------------------------------
  function get_prod_family_og_fun(p_cod_og in varchar2) return varchar2 is
    lv_cod_pf varchar2(3);
  begin
    select min(t.pilch_cod_prdfm_pilch) -- as product_family
      into lv_cod_pf
    --t.cod_cnt_autcc         as order_group
      from sal.sal_automatical_char_contents t
     where t.pilch_titde_cod_char_titde = '3902'
       and t.cod_cnt_autcc = p_cod_og;
    return lv_cod_pf;
  end;
  ----------------------
  function get_pf_id_fun(p_cod_pf in varchar2) return number is
    lv_pf_id number;
  begin
    select pf.bas_product_family_id
      into lv_pf_id
      from lmp.lmp_bas_product_families pf, mam_items mi
     where mi.item_id = pf.item_item_id
       and mi.cod_product_family_item = p_cod_pf;
    return lv_pf_id;
  exception
    when others then
      return 0;
  end;
  ------------------------------------
  procedure update_order_plan_prc(p_cod_run in varchar2) is
  begin
    update lmp_bas_orders o
       set o.qty_smc_prod_lmpor =
           (select sum(po.qty_prod_ppord)
              from lmp_sop_prod_plan_orders po
             where po.cod_order_ppord = o.cod_order_lmpor
               and po.cod_station_ppord = 41
               and po.num_item_ppord = o.num_order_lmpor
               and po.cod_run_ppord = p_cod_run),
           o.qty_hsm_prod_lmpor =
           (select sum(po.qty_prod_ppord)
              from lmp_sop_prod_plan_orders po
             where po.cod_order_ppord = o.cod_order_lmpor
               and po.cod_station_ppord = 45
               and po.num_item_ppord = o.num_order_lmpor
               and po.cod_run_ppord = p_cod_run)
     where o.cod_run_lmpor = p_cod_run
       and o.flg_active_in_model_lmpor = 1;
  end;
  -------------------------------------------
  procedure update_tot_need_order_prc(p_cod_run in varchar2) is
    --lv_upd_demand number;
  begin
    for i in (select o.bas_order_id,
                     o.cod_order_lmpor,
                     o.num_order_lmpor,
                     o.qty_demand_lmpor,
                     nvl(ss.qty_mu_Gsnap, 0) as qty_mu_Gsnap
                from lmp.lmp_bas_orders o,
                     (select s.Cod_Order_Gsnap,
                             s.Num_Order_Item_Gsnap,
                             sum((s.Wei_Mu_Gsnap) * oc.qty_yq_orfig *
                                 oc.qty_yw_orfig / 100) as qty_mu_Gsnap
                        from apps.mas_snapshot_viw     s,
                             lmp.lmp_bas_order_configs oc,
                             lmp.lmp_bas_stations      st
                       where s.Cod_Area_Id_a_Gsnap = st.area_area_id
                         and st.bas_station_id = oc.statn_bas_station_id
                         and oc.cod_ord_header_orfig = s.Cod_Order_Gsnap
                         and oc.num_item_orfig = s.Num_Order_Item_Gsnap
                         and oc.lkp_group_orfig = 'LMP'
                         and st.lkp_region_statn in ('HSM', 'SHP')
                       group by s.Cod_Order_Gsnap, s.Num_Order_Item_Gsnap) ss
               where o.cod_run_lmpor = p_cod_run
                 and o.cod_order_lmpor = ss.Cod_Order_Gsnap(+)
                 and o.num_order_lmpor = ss.Num_Order_Item_Gsnap(+)
                 and o.qty_demand_lmpor < nvl(ss.qty_mu_Gsnap, 0)
                 and o.flg_active_in_model_lmpor = 1
                 and o.cod_order_group_lmpor <= '10') loop
    
      update lmp.lmp_bas_orders t
         set t.qty_demand_lmpor = round(i.qty_mu_gsnap)
       where t.bas_order_id = i.bas_order_id;
    
    end loop;
  end;
  -------------------------------------
  procedure fill_inv_report_prc(p_cod_run in varchar2) is
    lv_first_inv        number;
    lv_last_inv         number;
    lv_prod             number;
    lv_sent             number;
    lv_start_dat        date;
    lv_end_dat          date;
    lv_pcn_nc_slab      number;
    lv_pcn_du_slab      number;
    lv_inv_extra        number;
    lv_inv_extra_temp   number;
    lv_send_shp         number;
    lv_nc_last_inv      number;
    lv_nc_last_inv_temp number;
    lv_sent_temp        number;
    lv_avg_pcn_nc       number;
  begin
    delete from lmp.lmp_cap_inv_reports ir
     where ir.cod_run_cainv = p_cod_run;
    select h.dat_strt_hrzn_rnhis, h.dat_end_hrzn_rnhis
      into lv_start_dat, lv_end_dat
      from lmp_bas_run_histories h
     where h.cod_run_rnhis = p_cod_run
       and h.num_module_rnhis = 3;
  
    select p.val_parameter_prmtr / 100
      into lv_pcn_nc_slab
      from lmp.lmp_bas_parameters p
     where p.cod_run_prmtr = '0'
       and p.num_module_prmtr = 3
       and p.nam_ful_latin_prmtr = 'PCN_NC_SLABS';
    select p.val_parameter_prmtr / 100
      into lv_pcn_du_slab
      from lmp.lmp_bas_parameters p
     where p.cod_run_prmtr = '0'
       and p.num_module_prmtr = 3
       and p.nam_ful_latin_prmtr = 'PCN_DU_SLABS';
  
    for i in (select t.bas_station_id, t.area_id, t.arstu_ide_pk_arstu
                from lmp_station_area_viw t
               where t.lkp_region_statn in ('HSM', 'SHP')) loop
    
      for og in (select distinct fp.val_att4_lmpfp
                   from lmp.lmp_bas_fix_params fp
                  where fp.lkp_typ_lmpfp = 'DAY_BY_DAY'
                 --and fp.val_att1_lmpfp = s.bas_station_id
                 ) loop
        lv_inv_extra   := 0;
        lv_nc_last_inv := 0;
        select sum(tt.Wei_Mu_Gsnap) / 1000
          into lv_first_inv
          from mas_snapshot_viw tt, lmp_bas_orders o
         where tt.Cod_Area_Id_a_Gsnap = i.area_id
           and o.cod_run_lmpor = p_cod_run
           and o.cod_order_lmpor = tt.Cod_Order_Gsnap
           and o.num_order_lmpor = tt.Num_Order_Item_Gsnap
           and o.flg_db_order_lmpor = tt.Flg_Db_Order_Gsnap
           and o.cod_order_group_lmpor = og.val_att4_lmpfp;
      
        for j in (select c.Dat_Calde
                    from aac_lmp_calendar_viw c
                   where c.Dat_Calde between lv_start_dat and lv_end_dat
                   order by c.Dat_Calde) loop
          lv_send_shp := 0;
          select sum(ip.qty_inventory_invpl)
            into lv_last_inv
            from lmp.lmp_bas_inv_plans ip
           where ip.cod_run_invpl = p_cod_run
             and ip.dat_day_invpl = j.dat_calde
             and ip.cod_statn_invpl = i.bas_station_id
             and ip.cod_order_group_invpl = og.val_att4_lmpfp;
        
          select sum(pp.qty_prod_prppf)
            into lv_prod
            from lmp.lmp_bas_production_plan_pfs pp
           where pp.cod_run_prppf = p_cod_run
             and pp.dat_day_prppf = j.dat_calde
             and pp.cod_statn_prppf = i.bas_station_id
             and pp.cod_order_group_prppf = og.val_att4_lmpfp;
        
          if i.arstu_ide_pk_arstu = 'M.S.C CO/M.S.C/SHIPMENT' then
          
            select sum(tp.qty_tranport_trapl) * lv_pcn_nc_slab
              into lv_inv_extra_temp
              from lmp.lmp_bas_transport_plans tp
             where tp.cod_run_trapl = p_cod_run
               and tp.cod_statn_to_trapl = i.bas_station_id
               and tp.cod_statn_from_trapl in
                   (select st.bas_station_id
                      from lmp_bas_stations st, pms_areas pa
                     where pa.area_id = st.area_area_id
                       and pa.arstu_ide_pk_arstu =
                           'M.S.C CO/M.S.C/SMC/CASTING AREA/CCM STATION/CCM')
               and tp.dat_day_trapl = j.dat_calde
               and tp.cod_order_group_trapl = og.val_att4_lmpfp;
          
            lv_inv_extra := lv_inv_extra + nvl(lv_inv_extra_temp, 0);
          
            select sum(tp.qty_tranport_trapl) * lv_pcn_du_slab
              into lv_inv_extra_temp
              from lmp.lmp_bas_transport_plans tp
             where tp.cod_run_trapl = p_cod_run
               and tp.cod_statn_to_trapl = i.bas_station_id
               and tp.cod_statn_from_trapl in
                   (select st.bas_station_id
                      from lmp_bas_stations st, pms_areas pa
                     where pa.area_id = st.area_area_id
                       and pa.arstu_ide_pk_arstu = 'M.S.C CO/M.S.C/HSM/HSM1')
               and tp.dat_day_trapl = j.dat_calde
               and tp.cod_order_group_trapl = og.val_att4_lmpfp;
          
            lv_inv_extra := lv_inv_extra + nvl(lv_inv_extra_temp, 0);
          
            select sum((tp.qty_tranport_trapl / nvl(tp.PCN_NC_TRAPL, 1)) *
                       (1 - nvl(tp.PCN_NC_TRAPL, 1)))
              into lv_nc_last_inv_temp
              from lmp.lmp_bas_transport_plans tp
             where tp.cod_run_trapl = p_cod_run
               and tp.dat_day_trapl = j.dat_calde
               and tp.cod_order_group_trapl = og.val_att4_lmpfp
            --and tp.cod_statn_to_trapl = i.bas_station_id
            ;
            lv_nc_last_inv := lv_nc_last_inv + nvl(lv_nc_last_inv_temp, 0);
          end if;
          select sum(tp.qty_tranport_trapl)
            into lv_sent
            from lmp.lmp_bas_transport_plans tp
           where tp.cod_run_trapl = p_cod_run
             and tp.cod_statn_to_trapl = i.bas_station_id
             and tp.dat_day_trapl = j.dat_calde
             and tp.cod_order_group_trapl = og.val_att4_lmpfp;
        
          if i.arstu_ide_pk_arstu = 'M.S.C CO/M.S.C/HSM/HSM1' then
            select nvl(sum(tp.qty_tranport_trapl), 0)
              into lv_send_shp
              from lmp.lmp_bas_transport_plans tp
             where tp.cod_run_trapl = p_cod_run
               and tp.cod_statn_to_trapl =
                   (select st.bas_station_id
                      from lmp_bas_stations st, pms_areas pa
                     where pa.area_id = st.area_area_id
                       and pa.arstu_ide_pk_arstu = 'M.S.C CO/M.S.C/SHIPMENT')
               and tp.cod_statn_from_trapl in
                   (select st.bas_station_id
                      from lmp_bas_stations st, pms_areas pa
                     where pa.area_id = st.area_area_id
                       and pa.arstu_ide_pk_arstu =
                           'M.S.C CO/M.S.C/SMC/CASTING AREA/CCM STATION/CCM')
               and tp.dat_day_trapl = j.dat_calde
               and tp.cod_order_group_trapl = og.val_att4_lmpfp;
          
            lv_nc_last_inv := lv_last_inv * lv_pcn_du_slab;
          
            select sum(stv.WEI_ASSIGNED_KG) / 1000
              into lv_sent_temp
              from mas_lmp_assigned_slab_typ_viw stv
             where stv.NUM_AREA_ID_LOC_AASTH in (160, 161, 162, 163)
               and stv.DAT_ARRIVAL = j.dat_calde;
          
            lv_sent := nvl(lv_sent, 0) + nvl(lv_sent_temp, 0);
          end if;
        
          insert into lmp.lmp_cap_inv_reports
            (cap_inv_report_id,
             statn_bas_station_id,
             cod_order_group_cainv,
             dat_plan_cainv,
             qty_first_cainv,
             qty_enter_cainv,
             qty_exit_cainv,
             qty_last_cainv,
             cod_run_cainv,
             QTY_SENT_DLV_CAINV,
             QTY_NC_LAST_INV_CAINV)
          values
            (lmp.lmp_cap_inv_reports_seq.nextval,
             i.bas_station_id,
             og.val_att4_lmpfp,
             j.dat_calde,
             lv_first_inv,
             lv_sent,
             lv_prod,
             lv_last_inv
             --+ round(nvl(lv_inv_extra_temp, 0), 3)
            ,
             p_cod_run,
             lv_send_shp,
             round(lv_nc_last_inv) + round(lv_inv_extra));
          lv_first_inv := lv_last_inv;
        end loop;
      end loop;
    
    end loop;
  end;
  -------------------------------------------
  function get_last_cod_run_fun return varchar2 DETERMINISTIC is
    lv_cod_run lmp_bas_run_histories.cod_run_rnhis%type;
  begin
  
    select t.cod_run_rnhis
      into lv_cod_run
      from lmp_bas_run_histories t
     where t.bas_run_history_id =
           (select max(h.bas_run_history_id)
              from lmp_bas_run_histories h
             where h.num_module_rnhis = 3
               and h.sta_run_rnhis = 1
               and h.sta_cnfrm_rnhis = 0);
    return lv_cod_run;
  end;
  ---------------------------------------------------
  procedure insert_inventory_plan_ord_prc(p_cod_pf     in number,
                                          p_ord_group  in varchar2,
                                          p_dat        in varchar2,
                                          p_qty        in number,
                                          p_cod_run    in varchar2,
                                          p_station_id in number) is
  begin
    insert into lmp_bas_inv_plans
      (bas_inv_plan_id,
       cod_profm_invpl,
       cod_run_invpl,
       cod_statn_invpl,
       dat_day_invpl,
       num_module_invpl,
       qty_inventory_invpl,
       COD_ORDER_GROUP_INVPL)
    values
      (lmp_bas_inv_plans_seq.nextval,
       p_cod_pf,
       p_cod_run,
       p_station_id,
       to_date(p_dat, 'YYYYMMDD', 'nls_calendar=persian'),
       3,
       p_qty,
       p_ord_group);
  end;
  -------------------------------------------------------------------
  procedure calculate_heat_number_prc(p_cod_run in varchar2) is
    lv_heat_ton number := 180;
    lv_num_heat number;
    lv_qty_rem  number;
    lv_qty_temp number;
    lv_lkp_typ  varchar2(20) := 'CAP_HEAT_NUM';
  begin
    lv_qty_rem := 0;
    delete from lmp.lmp_bas_fix_params t
     where t.val_att4_lmpfp = p_cod_run
       and t.lkp_typ_lmpfp = 'CAP_HEAT_NUM';
    for i in (select t.dat_day_prppf,
                     sum(t.qty_prod_prppf) / 0.97 as qty_prod_prppf
                from lmp_bas_production_plan_pfs t
               where t.cod_run_prppf = p_cod_run
                 and t.cod_statn_prppf = 41
               group by t.dat_day_prppf
               order by t.dat_day_prppf) loop
      lv_qty_temp := i.qty_prod_prppf + lv_qty_rem;
      lv_num_heat := round(lv_qty_temp / lv_heat_ton);
      lv_qty_rem  := lv_qty_temp - (lv_num_heat * lv_heat_ton);
      insert into lmp.lmp_bas_fix_params
        (bas_fix_param_id,
         val_att1_lmpfp,
         val_att2_lmpfp,
         val_att3_lmpfp,
         val_att4_lmpfp,
         lkp_typ_lmpfp)
      values
        (lmp.lmp_bas_fix_params_seq.nextval,
         lv_num_heat,
         lv_num_heat * lv_heat_ton,
         to_char(i.dat_day_prppf, 'YYYYMMDD', 'nls_calendar=persian'),
         p_cod_run,
         lv_lkp_typ);
    end loop;
  end;
  --------------------------------
  function get_last_run_date_fun return date DETERMINISTIC is
    lv_dat date;
  begin
    select t.dat_run_rnhis
      into lv_dat
      from lmp_bas_run_histories t
     where t.cod_run_rnhis = APP_LMP_CAP_TOT_MODEL_PKG.get_last_cod_run_fun
       and t.num_module_rnhis = 3;
    return lv_dat;
  exception
    when others then
      return null;
  end;
  ----------------------------------
  procedure calculate_heat_cap_prc(p_cod_run in varchar2) is
    lv_start_dat date;
    lv_end_dat   date;
    lv_cap       number;
    lv_max_cap   number;
    lv_max_fur   number := 4;
    lv_stop_hour number;
    lv_qty_temp  number;
    lv_qty_rem   number := 0;
    lv_num_heat  number;
  begin
    delete from lmp.lmp_cap_heat_plans t where t.cod_run_hetpl = p_cod_run;
    select h.dat_strt_hrzn_rnhis, h.dat_end_hrzn_rnhis
      into lv_start_dat, lv_end_dat
      from lmp.lmp_bas_run_histories h
     where h.cod_run_rnhis = p_cod_run
       and h.num_module_rnhis = 3;
    for i in (select c.Dat_Calde
                from aac_lmp_calendar_viw c
               where c.Dat_Calde between lv_start_dat and lv_end_dat) loop
      lv_cap := 0;
      for j in 1 .. lv_max_fur loop
        begin
          select nvl(fp.val_att7_lmpfp, 0)
            into lv_max_cap
            from lmp_bas_fix_params fp
           where fp.lkp_typ_lmpfp = 'FURNACE_CAPACITY'
             and fp.val_att1_lmpfp = j;
        exception
          when no_data_found then
            lv_max_cap := 0;
        end;
        begin
          select nvl(fp.val_att7_lmpfp, 0)
            into lv_stop_hour
            from lmp.lmp_bas_fix_params fp
           where fp.lkp_typ_lmpfp = 'FURNACE_STOP'
             and fp.val_att1_lmpfp = j
             and fp.DAT_ATT_LMPFP = i.dat_calde;
        exception
          when no_data_found then
            lv_stop_hour := 0;
        end;
        lv_cap := lv_cap + ((24 - lv_stop_hour) / 24) * lv_max_cap;
      end loop;
    
      lv_qty_temp := lv_cap + lv_qty_rem;
      lv_num_heat := round(lv_qty_temp);
      lv_qty_rem  := lv_qty_temp - lv_num_heat;
    
      insert into lmp.lmp_cap_heat_plans
        (cap_heat_plan_id,
         cod_run_hetpl,
         dat_day_hetpl,
         num_heat_cap_hetpl)
      values
        (lmp.lmp_cap_heat_plans_seq.nextval,
         p_cod_run,
         i.dat_calde,
         lv_num_heat);
    end loop;
  end;
  -------------------------------
  procedure calculate_capacity_prc(p_cod_run in varchar2) is
    lv_cap_heat      number;
    lv_start_dat     date;
    lv_end_dat       date;
    lv_stop          number;
    lv_cap_heat_temp number;
    lv_cap           number;
    lv_cap_temp      number;
    lv_pcn_nc_slab   number := 0;
    lv_pcn_du_slab   number := 0;
    lv_dat_start_smc date;
    lv_3heat_coef    number := 0.95;
    lv_2heat_coef    number := 0.69;
    lv_avail_inv     number;
    lv_min_inv_cap   number;
    lv_pcn_cap       number;
    lv_last_hsm_time date :=apps.api_mas_run_simulators_pkg.return_hsm_available_time_fun;
  begin
    select h.dat_strt_hrzn_rnhis, h.dat_end_hrzn_rnhis
      into lv_start_dat, lv_end_dat
      from lmp.lmp_bas_run_histories h
     where h.cod_run_rnhis = p_cod_run;
  
  
    lv_dat_start_smc := apps.api_mas_lmp_pkg.get_max_dat_prog_smc_Fun(apps.api_mas_models_pkg.Get_Last_AAS_Cod_Run_Fun);
  
    /*select p.val_parameter_prmtr
     into lv_pcn_nc_slab
     from lmp.lmp_bas_parameters p
    where p.cod_run_prmtr = '0'
      and p.num_module_prmtr = 3
      and p.nam_ful_latin_prmtr = 'PCN_NC_SLABS';*/
    /*select p.val_parameter_prmtr
     into lv_pcn_du_slab
     from lmp.lmp_bas_parameters p
    where p.cod_run_prmtr = '0'
      and p.num_module_prmtr = 3
      and p.nam_ful_latin_prmtr = 'PCN_DU_SLABS';*/
  
    for j in (select c.Dat_Calde
                from aac_lmp_calendar_viw c
               where c.Dat_Calde between lv_start_dat and lv_end_dat) loop
      lv_cap_heat := 0;
      for i in (select t.val_att1_lmpfp as num_furnace,
                       t.val_att2_lmpfp as pdw,
                       t.val_att7_lmpfp as iu
                  from lmp.lmp_bas_fix_params t
                 where t.lkp_typ_lmpfp = 'FURNACE_CAPACITY') loop
        begin
          select nvl(sum(nvl(fp.val_att7_lmpfp, 0) +
                         nvl(fp.val_att8_lmpfp, 0)),
                     0)
            into lv_stop
            from lmp.lmp_bas_fix_params fp
           where fp.lkp_typ_lmpfp = 'FURNACE_STOP'
             and fp.val_att1_lmpfp = i.num_furnace
             and fp.dat_att_lmpfp = j.dat_calde;
        exception
          when no_data_found then
            lv_stop := 0;
        end;
        lv_cap_heat_temp := (24 - lv_stop) * i.iu * i.pdw;
        insert into lmp.lmp_cap_heat_plans
          (cap_heat_plan_id,
           dat_day_hetpl,
           cod_run_hetpl,
           num_furnace_hetpl,
           QTY_MAX_TON_HETPL,
           LKP_TYP_HETPL)
        values
          (lmp.lmp_cap_heat_plans_seq.nextval,
           j.dat_calde,
           p_cod_run,
           i.num_furnace,
           lv_cap_heat_temp,
           'تعداد');
        lv_cap_heat := lv_cap_heat + lv_cap_heat_temp;
      end loop;
      insert into lmp.lmp_bas_capacities
        (bas_capacity_id,
         statn_bas_station_id,
         dat_day_bacap,
         cod_run_bacap,
         qty_capacity_bacap)
      values
        (lmp.lmp_bas_capacities_seq.nextval,
         null,
         j.dat_calde,
         p_cod_run,
         lv_cap_heat);
    end loop;
  
    for d in (select c.Dat_Calde
                from aac_lmp_calendar_viw c
               where c.Dat_Calde between lv_start_dat and lv_end_dat) loop
      --CCM
      lv_cap := 0;
    
      for t in (select t1.bas_station_id,
                       nvl(t1.val_prod_modifier_statn, 0) as val_prod_modifier_statn,
                       nvl(t2.qty_maintenace_camai, 0) as qty_maintenace_camai
                  from (select *
                          from (select st.bas_station_id,
                                       st.val_prod_modifier_statn
                                  from lmp.lmp_bas_stations st, pms_areas pa
                                 where st.area_area_id = pa.area_id
                                   and pa.arstu_ide_pk_arstu =
                                       'M.S.C CO/M.S.C/SMC/CASTING AREA/CCM STATION/CCM'),
                               (select c.Dat_Calde
                                  from aac_lmp_calendar_viw c
                                 where c.Dat_Calde = d.dat_calde)) t1,
                       (select m.statn_bas_station_id,
                               m.dat_day_camai,
                               nvl(m.qty_maintenace_camai, 0) +
                               nvl(m.qty_inactive_camai, 0) +
                               nvl(m.qty_service_camai, 0) +
                               nvl(m.qty_crane_camai, 0) as qty_maintenace_camai
                          from lmp.lmp_cap_maintenances m
                         where m.dat_day_camai = d.dat_calde) t2
                 where t1.dat_calde = t2.dat_day_camai(+)
                   and t1.bas_station_id = t2.statn_bas_station_id(+)) loop
        lv_cap := lv_cap + ((24 - t.qty_maintenace_camai) *
                  t.val_prod_modifier_statn);
      end loop;
      if d.dat_calde > lv_dat_start_smc then
        insert into lmp.lmp_bas_capacities
          (bas_capacity_id,
           statn_bas_station_id,
           dat_day_bacap,
           qty_capacity_bacap,
           cod_run_bacap --,
           --QTY_MINUES_CAP_BACAP
           )
        values
          (lmp.lmp_bas_capacities_seq.nextval,
           41,
           d.dat_calde,
           round(lv_cap * ((100 - (lv_pcn_du_slab + lv_pcn_nc_slab)) / 100),
                 3),
           p_cod_run /*,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                round(lv_cap * ((lv_pcn_du_slab + lv_pcn_nc_slab) / 100), 3)*/);
      
      end if;
    
      --Send to HSM
      for t in (select t1.bas_station_id,
                       t1.arstu_ide_pk_arstu,
                       t1.qty_prod_cap_statn,
                       nvl(t1.val_prod_modifier_statn, 0) as val_prod_modifier_statn,
                       nvl(t2.qty_maintenace_camai, 0) as qty_maintenace_camai
                  from (select *
                          from (select st.bas_station_id,
                                       st.val_prod_modifier_statn,
                                       st.qty_prod_cap_statn,
                                       pa.arstu_ide_pk_arstu
                                  from lmp.lmp_bas_stations st, pms_areas pa
                                 where st.area_area_id = pa.area_id
                                   and pa.arstu_ide_pk_arstu =
                                       'M.S.C CO/M.S.C/SMC/SLAB-CONDITIONING/PULPIT-9'),
                               (select c.Dat_Calde
                                  from aac_lmp_calendar_viw c
                                 where c.Dat_Calde = d.dat_calde)) t1,
                       (select m.statn_bas_station_id,
                               m.dat_day_camai,
                               nvl(m.qty_maintenace_camai, 0) +
                               nvl(m.qty_inactive_camai, 0) +
                               nvl(m.qty_service_camai, 0) +
                               nvl(m.qty_crane_camai, 0) as qty_maintenace_camai,
                               m.num_furnace_camai
                          from lmp.lmp_cap_maintenances m
                         where m.dat_day_camai = d.dat_calde) t2
                 where t1.dat_calde = t2.dat_day_camai(+)
                   and t1.bas_station_id = t2.statn_bas_station_id(+)) loop
        -------------------------- ADDED BY S.SAEIDI 13990905
        if trunc(d.Dat_Calde) = trunc(sysdate) then
        
          lv_cap_temp := (greatest(t.qty_prod_cap_statn *
                                   ((18.5 - (sysdate - trunc(sysdate)) * 24) / 24),
                                   0) * t.val_prod_modifier_statn);
        else
        
          lv_cap_temp := (greatest(t.qty_prod_cap_statn *
                                   (1 - (t.qty_maintenace_camai / 24)),
                                   0) * t.val_prod_modifier_statn);
        end if;
        insert into lmp.lmp_bas_capacities
          (bas_capacity_id,
           statn_bas_station_id,
           dat_day_bacap,
           qty_capacity_bacap,
           cod_run_bacap)
        values
          (lmp.lmp_bas_capacities_seq.nextval,
           t.bas_station_id,
           d.dat_calde,
           lv_cap_temp,
           p_cod_run);
      
      end loop;
    
      --HSM
      for t in (select t1.bas_station_id,
                       t1.arstu_ide_pk_arstu,
                       t1.qty_prod_cap_statn,
                       nvl(t1.val_prod_modifier_statn, 0) as val_prod_modifier_statn,
                       nvl(t2.qty_maintenace_camai, 0) as qty_maintenace_camai,
                       t2.num_furnace_camai
                  from (select *
                          from (select st.bas_station_id,
                                       st.val_prod_modifier_statn,
                                       st.qty_prod_cap_statn,
                                       pa.arstu_ide_pk_arstu
                                  from lmp.lmp_bas_stations st, pms_areas pa
                                 where st.area_area_id = pa.area_id
                                   and pa.arstu_ide_pk_arstu like
                                       'M.S.C CO/M.S.C/HSM%'),
                               (select c.Dat_Calde
                                  from aac_lmp_calendar_viw c
                                 where c.Dat_Calde = d.dat_calde)) t1,
                       (select m.statn_bas_station_id,
                               m.dat_day_camai,
                               nvl(m.qty_maintenace_camai, 0) +
                               nvl(m.qty_inactive_camai, 0) +
                               nvl(m.qty_service_camai, 0) +
                               nvl(m.qty_crane_camai, 0) as qty_maintenace_camai,
                               m.num_furnace_camai
                          from lmp.lmp_cap_maintenances m
                         where m.dat_day_camai = d.dat_calde) t2
                 where t1.dat_calde = t2.dat_day_camai(+)
                   and t1.bas_station_id = t2.statn_bas_station_id(+)) loop
        lv_cap_temp := (greatest(t.qty_prod_cap_statn -
                                 t.qty_maintenace_camai,
                                 0) * t.val_prod_modifier_statn);
        if t.num_furnace_camai = 3 then
          lv_cap_temp := lv_cap_temp * lv_3heat_coef;
        end if;
        if t.num_furnace_camai = 2 then
          lv_cap_temp := lv_cap_temp * lv_2heat_coef;
        end if;
        ----------------------------------Calc_Available----Added by Hr.Ebrahimi 13991204--Edited 14000218
        if t.arstu_ide_pk_arstu = 'M.S.C CO/M.S.C/HSM/HSM1' then
        
         if ((trunc(d.Dat_Calde) + 18.5 / 24) <= lv_last_hsm_time/*apps.api_mas_run_simulators_pkg.return_hsm_available_time_fun*/) then
            lv_pcn_cap:=0;
           
         elsif ((trunc(d.Dat_Calde) + 18.5 / 24) > lv_last_hsm_time/*apps.api_mas_run_simulators_pkg.return_hsm_available_time_fun*/ ) 
                and((trunc(d.Dat_Calde - 1) + 18.5 / 24) <lv_last_hsm_time/*apps.api_mas_run_simulators_pkg.return_hsm_available_time_fun*/ ) then
            
              lv_pcn_cap:=((trunc(d.Dat_Calde) + 18.5 / 24) -greatest((trunc(d.Dat_Calde - 1) + 18.5 / 24),lv_last_hsm_time/*apps.api_mas_run_simulators_pkg.return_hsm_available_time_fun*/)) ;
    
        else
            lv_pcn_cap:=1;
        end if;
            
         
          
--------------------------------------------- 
          insert into lmp.lmp_bas_capacities
            (bas_capacity_id,
             statn_bas_station_id,
             dat_day_bacap,
             qty_capacity_bacap,
             cod_run_bacap)
          values
            (lmp.lmp_bas_capacities_seq.nextval,
             t.bas_station_id,
             d.dat_calde,
             greatest(round(lv_pcn_cap*lv_cap_temp * ((100 - lv_pcn_du_slab) / 100), 3),0),    
             --greatest(round(1*lv_cap_temp * ((100 - lv_pcn_du_slab) / 100), 3),0),
             p_cod_run);
        else
        
          insert into lmp.lmp_bas_capacities
            (bas_capacity_id,
             statn_bas_station_id,
             dat_day_bacap,
             qty_capacity_bacap,
             cod_run_bacap)
          values
            (lmp.lmp_bas_capacities_seq.nextval,
             t.bas_station_id,
             d.dat_calde,
             lv_cap_temp,
             p_cod_run);
        end if;
      end loop;
    
      --CRM
      for t in (select t1.bas_station_id,
                       t1.arstu_ide_pk_arstu,
                       t1.qty_prod_cap_statn,
                       nvl(t1.val_prod_modifier_statn, 0) as val_prod_modifier_statn,
                       nvl(t2.qty_maintenace_camai, 0) as qty_maintenace_camai,
                       t2.num_furnace_camai
                  from (select *
                          from (select st.bas_station_id,
                                       st.val_prod_modifier_statn,
                                       st.qty_prod_cap_statn,
                                       pa.arstu_ide_pk_arstu
                                  from lmp.lmp_bas_stations st, pms_areas pa
                                 where st.area_area_id = pa.area_id
                                   and pa.arstu_ide_pk_arstu like
                                       'M.S.C CO/M.S.C/CCM%'),
                               (select c.Dat_Calde
                                  from aac_lmp_calendar_viw c
                                 where c.Dat_Calde = d.dat_calde)) t1,
                       (select m.statn_bas_station_id,
                               m.dat_day_camai,
                               nvl(m.qty_maintenace_camai, 0) +
                               nvl(m.qty_inactive_camai, 0) +
                               nvl(m.qty_service_camai, 0) +
                               nvl(m.qty_crane_camai, 0) as qty_maintenace_camai,
                               m.num_furnace_camai
                          from lmp.lmp_cap_maintenances m
                         where m.dat_day_camai = d.dat_calde) t2
                 where t1.dat_calde = t2.dat_day_camai(+)
                   and t1.bas_station_id = t2.statn_bas_station_id(+)) loop
        lv_cap_temp := (greatest(t.qty_prod_cap_statn -
                                 t.qty_maintenace_camai,
                                 0) * t.val_prod_modifier_statn);
      
        insert into lmp.lmp_bas_capacities
          (bas_capacity_id,
           statn_bas_station_id,
           dat_day_bacap,
           qty_capacity_bacap,
           cod_run_bacap)
        values
          (lmp.lmp_bas_capacities_seq.nextval,
           t.bas_station_id,
           d.dat_calde,
           lv_cap_temp,
           p_cod_run);
      end loop;
    
      --SHP
      for t in (select st.bas_station_id, st.qty_prod_cap_statn
                  from lmp_bas_stations st
                 where st.bas_station_id = 46) loop
        lv_cap_temp := nvl(t.qty_prod_cap_statn, 0);
      
        insert into lmp.lmp_bas_capacities
          (bas_capacity_id,
           statn_bas_station_id,
           dat_day_bacap,
           qty_capacity_bacap,
           cod_run_bacap)
        values
          (lmp.lmp_bas_capacities_seq.nextval,
           t.bas_station_id,
           d.dat_calde,
           lv_cap_temp,
           p_cod_run);
      end loop;
    end loop;
    
    --min_inventory
    for s in (select st.bas_station_id,
                     pa.area_id,
                     nvl(st.qty_min_inv_statn, 0) qty_min_inv_statn
                from lmp.lmp_bas_stations st, pms_areas pa
               where pa.area_id = st.area_area_id
                 and pa.arstu_ide_pk_arstu not like 'M.S.C CO/M.S.C/CCM%') loop
      lv_min_inv_cap := s.qty_min_inv_statn;
      select round(sum(im.mu_wei) / 1000)
        into lv_avail_inv
        from mas_lmp_initial_mu_viw im, lmp.lmp_bas_orders o
       where im.station_id = s.bas_station_id
         and o.cod_run_lmpor = p_cod_run
         and o.flg_active_in_model_lmpor = 1
         and o.cod_order_lmpor = im.cod_ord_ordhe
         and o.num_order_lmpor = im.num_item_ordit;
      if lv_avail_inv < lv_min_inv_cap then
        for c in (select cal.Dat_Calde
                    from aac_lmp_calendar_viw cal
                   where cal.Dat_Calde between lv_start_dat and lv_end_dat
                   order by cal.Dat_Calde) loop
          lv_avail_inv := lv_avail_inv * 1.05;
          if lv_avail_inv >= lv_min_inv_cap then
            exit;
          end if;
          insert into lmp.lmp_cap_dbd_inputs
            (cap_dbd_input_id,
             statn_bas_station_id,
             dat_day_dbdin,
             lkp_typ_dbdin,
             cod_run_dbdin,
             qty_min_dbdin)
          values
            (lmp.lmp_cap_dbd_inputs_seq.nextval,
             s.bas_station_id,
             c.dat_calde,
             'INVENTORY_CAPACITY',
             p_cod_run,
             round(lv_avail_inv));
        end loop;
      end if;
    end loop;
  
  end;
  -----------------------------------------
  procedure calculate_heat_plan_prc(p_cod_run in varchar2) is
    lv_heat_ton     number := 180;
    lv_remain       number := 0;
    lv_smc_ton      number;
    LV_SUM_HEAT     number;
    lv_sum_cap_heat number;
    lv_heat_slab    number;
  begin
    select p.val_parameter_prmtr
      into lv_heat_slab
      from lmp.lmp_bas_parameters p
     where p.num_module_prmtr = 3
       and p.cod_run_prmtr = '0'
       and p.nam_ful_latin_prmtr = 'CAP_HEAT_SLAB';
  
    select p.val_parameter_prmtr
      into lv_heat_ton
      from lmp.lmp_bas_parameters p
     where p.num_module_prmtr = 3
       and p.cod_run_prmtr = '0'
       and p.nam_ful_latin_prmtr = 'CAP_HEAT_TON';
  
    lv_heat_ton := lv_heat_ton / lv_heat_slab;
  
    for i in (select cp.dat_day_cappl dat_day_prppf,
                     sum(cp.qty_used_ton_cappl) / lv_heat_slab as sum_prod,
                     sum(cp.qty_used_ton_cappl) as ccm_ton,
                     sum(cp.pcn_cap_cappl) as pcn_ccm
                from lmp_bas_capacity_plans cp,
                     lmp_bas_stations       st,
                     pms_areas              pa
               where cp.cod_run_cappl = p_cod_run
                 and cp.cod_station_cappl = st.bas_station_id
                 and st.area_area_id = pa.area_id
                 and cp.num_module_cappl = 3
                 and pa.arstu_ide_pk_arstu =
                     'M.S.C CO/M.S.C/SMC/CASTING AREA/CCM STATION/CCM'
               group by cp.dat_day_cappl
               order by cp.dat_day_cappl) loop
      lv_smc_ton      := i.sum_prod;
      LV_SUM_HEAT     := 0;
      lv_sum_cap_heat := 0;
      for j in (select chp.cap_heat_plan_id,
                       chp.num_furnace_hetpl,
                       nvl(chp.qty_max_ton_hetpl, 0) qty_max_ton_hetpl
                  from lmp.lmp_cap_heat_plans chp
                 where chp.cod_run_hetpl = p_cod_run
                   and chp.dat_day_hetpl = i.dat_day_prppf
                   and chp.qty_max_ton_hetpl > 0
                 order by chp.num_furnace_hetpl) loop
        lv_sum_cap_heat := lv_sum_cap_heat + j.qty_max_ton_hetpl;
        if lv_smc_ton >= j.qty_max_ton_hetpl then
        
          lv_smc_ton := lv_smc_ton - round((round(lv_remain + (j.qty_max_ton_hetpl /
                                                  lv_heat_ton)) *
                                           lv_heat_ton));
          update lmp.lmp_cap_heat_plans t
             set t.qty_plan_hetpl = round(lv_remain +
                                          (j.qty_max_ton_hetpl / lv_heat_ton)),
                 t.NUM_SEQ_HETPL =
                 (j.num_furnace_hetpl * 10) + 2
           where t.cap_heat_plan_id = j.cap_heat_plan_id;
          LV_SUM_HEAT := LV_SUM_HEAT + round(lv_remain + (j.qty_max_ton_hetpl /
                                             lv_heat_ton));
          insert into lmp.lmp_cap_heat_plans
            (cap_heat_plan_id,
             cod_run_hetpl,
             dat_day_hetpl,
             num_furnace_hetpl,
             lkp_typ_hetpl,
             qty_plan_hetpl,
             NUM_SEQ_HETPL)
          values
            (lmp.lmp_cap_heat_plans_seq.nextval,
             p_cod_run,
             i.dat_day_prppf,
             j.num_furnace_hetpl,
             'وزن ذوب (تن)',
             round(round(lv_remain + (j.qty_max_ton_hetpl / lv_heat_ton)) *
                   lv_heat_ton),
             (j.num_furnace_hetpl * 10) + 1);
          lv_remain := (lv_remain + (j.qty_max_ton_hetpl / lv_heat_ton)) -
                       round(lv_remain +
                             (j.qty_max_ton_hetpl / lv_heat_ton));
        else
        
          update lmp.lmp_cap_heat_plans t
             set t.qty_plan_hetpl = round(lv_remain +
                                          (lv_smc_ton / lv_heat_ton)),
                 t.NUM_SEQ_HETPL =
                 (j.num_furnace_hetpl * 10) + 2
           where t.cap_heat_plan_id = j.cap_heat_plan_id;
        
          LV_SUM_HEAT := LV_SUM_HEAT +
                         round(lv_remain + (lv_smc_ton / lv_heat_ton));
          insert into lmp.lmp_cap_heat_plans
            (cap_heat_plan_id,
             cod_run_hetpl,
             dat_day_hetpl,
             num_furnace_hetpl,
             lkp_typ_hetpl,
             qty_plan_hetpl,
             NUM_SEQ_HETPL)
          values
            (lmp.lmp_cap_heat_plans_seq.nextval,
             p_cod_run,
             i.dat_day_prppf,
             j.num_furnace_hetpl,
             'وزن ذوب (تن)',
             round(round(lv_remain + (lv_smc_ton / lv_heat_ton)) *
                   lv_heat_ton),
             (j.num_furnace_hetpl * 10) + 1);
          lv_remain  := (lv_remain + (lv_smc_ton / lv_heat_ton)) -
                        round(lv_remain + (lv_smc_ton / lv_heat_ton));
          lv_smc_ton := 0;
        
        end if;
      
      end loop;
    
      insert into lmp.lmp_cap_heat_plans
        (cap_heat_plan_id,
         cod_run_hetpl,
         dat_day_hetpl,
         num_furnace_hetpl,
         lkp_typ_hetpl,
         qty_plan_hetpl,
         NUM_SEQ_HETPL)
      values
        (lmp.lmp_cap_heat_plans_seq.nextval,
         p_cod_run,
         i.dat_day_prppf,
         0,
         'وزن ريخته گري (تن)',
         i.ccm_ton,
         1);
    
      insert into lmp.lmp_cap_heat_plans
        (cap_heat_plan_id,
         cod_run_hetpl,
         dat_day_hetpl,
         num_furnace_hetpl,
         lkp_typ_hetpl,
         qty_plan_hetpl,
         NUM_SEQ_HETPL,
         TYP_PLAN_HETPL)
      values
        (lmp.lmp_cap_heat_plans_seq.nextval,
         p_cod_run,
         i.dat_day_prppf,
         0,
         'تعداد ذوب',
         LV_SUM_HEAT,
         5,
         'TOT_HEAT_NUM');
    
      insert into lmp.lmp_cap_heat_plans
        (cap_heat_plan_id,
         cod_run_hetpl,
         dat_day_hetpl,
         num_furnace_hetpl,
         lkp_typ_hetpl,
         qty_plan_hetpl,
         NUM_SEQ_HETPL,
         TYP_PLAN_HETPL)
      values
        (lmp.lmp_cap_heat_plans_seq.nextval,
         p_cod_run,
         i.dat_day_prppf,
         0,
         'وزن ذوب (تن)',
         round(LV_SUM_HEAT * lv_heat_ton),
         3,
         'TOT_HEAT_TON');
    
      insert into lmp.lmp_cap_heat_plans
        (cap_heat_plan_id,
         cod_run_hetpl,
         dat_day_hetpl,
         num_furnace_hetpl,
         lkp_typ_hetpl,
         qty_plan_hetpl,
         NUM_SEQ_HETPL)
      values
        (lmp.lmp_cap_heat_plans_seq.nextval,
         p_cod_run,
         i.dat_day_prppf,
         0,
         'درصد تکميل کوره ها',
         round(((LV_SUM_HEAT * lv_heat_ton) / lv_sum_cap_heat) * 100),
         4);
    
      insert into lmp.lmp_cap_heat_plans
        (cap_heat_plan_id,
         cod_run_hetpl,
         dat_day_hetpl,
         num_furnace_hetpl,
         lkp_typ_hetpl,
         qty_plan_hetpl,
         NUM_SEQ_HETPL)
      values
        (lmp.lmp_cap_heat_plans_seq.nextval,
         p_cod_run,
         i.dat_day_prppf,
         0,
         'درصد تکميل ريخته گري',
         i.pcn_ccm,
         2);
    
    end loop;
  
  end;

  -------------------------------------------
  procedure insert_ord_pririty_mis_prc(p_cod_run in varchar2) is
    lv_string          varchar2(200);
    lv_num_day         number := 0;
    lv_start_day       date;
    lv_end_day         date;
    lv_cod_urg         number;
    lv_wid_slab        number;
    lv_cod_prod_family varchar2(2);
    lv_lth_typ         varchar2(4);
    lv_cal             number;
    lv_lth             number;
    lv_id              number := 0;
    lv_num             number;
    --p_cod_run varchar2(20);
    lv_urg    varchar2(1);
    lv_prio   varchar2(3);
    lv_order  varchar2(11);
    lv_kg     varchar2(9);
    lv_ttt    varchar2(5);
    lv_hsm_yw number;
  begin
    execute immediate 'alter session set nls_calendar=''persian''';
    --p_cod_run:=apps.APP_LMP_CAP_TOT_MODEL_PKG.get_last_cod_run_fun;
    select h.dat_strt_hrzn_rnhis, h.dat_end_hrzn_rnhis
      into lv_start_day, lv_end_day
      from lmp.lmp_bas_run_histories h
     where h.cod_run_rnhis = p_cod_run
       and h.num_module_rnhis = 3;
  
    for d in (select c.Dat_Calde
                from apps.lmp_aac_calendar_viw c
               where c.Dat_Calde between lv_start_day and lv_end_day
               order by c.Dat_Calde) loop
      lv_num_day := lv_num_day + 1;
    
      for i in (select o.cod_order_lmpor,
                       o.num_order_lmpor,
                       o.cod_ord_mis_lmpor,
                       o.cod_internal_ord_lmpor,
                       o.cod_order_group_lmpor,
                       po.dat_day_ppord,
                       to_char(o.dat_dlv_lmpor, 'YYYYMMDD') as dat_dlv_lmpor,
                       o.val_datlast_hsm_lmpor,
                       round(po.qty_prod_ppord * 1000) as qty_kg,
                       o.flg_from_hsm_lmpor,
                       case
                         when substr(o.cod_order_lmpor, 3, 1) = '9' then
                          0
                         else
                          1
                       end
                  from lmp.lmp_sop_prod_plan_orders po, lmp.lmp_bas_orders o
                 where po.cod_run_ppord = p_cod_run
                   and po.cod_station_ppord = 45
                   and po.dat_day_ppord = d.dat_calde
                   and o.cod_run_lmpor = po.cod_run_ppord
                   and o.cod_order_lmpor = po.cod_order_ppord
                   and o.num_order_lmpor = po.num_item_ppord
                 order by o.flg_from_hsm_lmpor,
                          o.flg_virtual_lmpor,
                          o.val_datlast_hsm_lmpor,
                          nvl(o.dat_agg_dlv_lmpor, o.dat_dlv_lmpor),
                          case
                            when substr(o.cod_order_lmpor, 3, 1) = '9' then
                             0
                            else
                             1
                          end) loop
      
        select oi.num_proirity_ordit,
               oi.cod_prod_family_ordit,
               oi.cod_wid_slab_ordit
          into lv_cod_urg, lv_cod_prod_family, lv_wid_slab
          from sal.sal_order_items oi
         where oi.ordhe_cod_ord_ordhe = i.cod_order_lmpor
           and oi.ordhe_flg_db_ordhe = 0
           and oi.num_item_ordit = i.num_order_lmpor;
      
        select oit.qty_orite
          into lv_lth_typ
          from sal.sal_order_item_technicals oit
         where oit.ordit_ordhe_cod_ord_ordhe = i.cod_order_lmpor
           and oit.ordit_num_item_ordit = i.num_order_lmpor
           and oit.ordit_ordhe_flg_db_ordhe = 0
           and oit.cod_char_orite = '3603';
      
        if lv_cod_urg is null then
          lv_string := '9';
        else
          lv_string := lv_cod_urg;
        end if;
        lv_urg    := lv_string;
        lv_string := lv_string || lpad(lv_num_day, 3, '0');
        lv_prio   := lpad(lv_num_day, 3, '0');
        if lv_cod_prod_family in ('05', '07') then
          lv_string := lv_string || i.cod_ord_mis_lmpor ||
                       lpad(i.num_order_lmpor, 3, '0');
          lv_order  := i.cod_ord_mis_lmpor ||
                       lpad(i.num_order_lmpor, 3, '0');
        else
          lv_order  := i.cod_internal_ord_lmpor;
          lv_string := lv_string || i.cod_internal_ord_lmpor;
        end if;
      
        select oc.qty_yw_orfig
          into lv_hsm_yw
          from lmp.lmp_bas_order_configs oc
         where oc.cod_ord_header_orfig = i.cod_order_lmpor
           and oc.num_item_orfig = i.num_order_lmpor
           and oc.statn_bas_station_id = 45
           AND OC.LKP_GROUP_ORFIG = 'LMP';
      
        lv_string := lv_string ||
                     lpad((round(i.qty_kg / (lv_hsm_yw / 100))), 9, '0');
        lv_kg     := lpad(i.qty_kg, 9, '0');
        if lv_lth_typ in ('2') then
          lv_lth := 450;
        else
          lv_lth := 950;
        end if;
      
        lv_cal := round(((lv_wid_slab * 7.61) / 10000) * 20.3 * lv_lth);
      
        lv_string := lv_string || lpad(lv_cal, 5, '0');
        lv_ttt    := lpad(lv_cal, 5, '0');
        --dbms_output.put_line(lv_string);
        lv_num := length(lv_string);
        if lv_num < 28 then
        
          dbms_output.put_line(i.cod_order_lmpor || '-' ||
                               i.num_order_lmpor || '-' ||
                               i.cod_ord_mis_lmpor || '-' ||
                               i.cod_internal_ord_lmpor);
          continue;
        end if;
        lv_string := lv_string || chr(10);
        lv_id     := lv_id + 1;
        /*if lv_id>2 then
          exit;
        end if;*/
        execute immediate 'insert into tpin_mis.lmp_tab_1_host5
          (id, data_1)
        values
          (:lv_id, :lv_string)'
          using lv_id, lv_string;
      
      /*insert into apps.global_temps
                                                                                                                                                                                                                                                                                                                                            (indx, att1, att2, att3, att4, att5, att6, att7, att8)
                                                                                                                                                                                                                                                                                                                                            values
                                                                                                                                                                                                                                                                                                                                            (global_temp_seq.nextval,
                                                                                                                                                                                                                                                                                                                                            lv_urg,
                                                                                                                                                                                                                                                                                                                                            lv_prio,
                                                                                                                                                                                                                                                                                                                                            lv_order,
                                                                                                                                                                                                                                                                                                                                            lv_kg,
                                                                                                                                                                                                                                                                                                                                            lv_ttt,
                                                                                                                                                                                                                                                                                                                                            i.dat_dlv_lmpor,
                                                                                                                                                                                                                                                                                                                                            i.val_datlast_hsm_lmpor,
                                                                                                                                                                                                                                                                                                                                            i.cod_order_group_lmpor);*/
      
      end loop;
    end loop;
    commit;
  end;
  -----------------------------------------
  procedure check_smp_ord_datlast_prc is
    lv_num number;
  begin
    for i in (select distinct t.ordhe_cod_ord_ordhe, t.num_item_ordit
                from apps.smp_mas_sal_order_plan_viw t
               where t.num_week_ccm_ordsl is null
                  or t.num_week_ccm_ordsl = '0') loop
      apps.app_lmp_dress_pkg.LMP_CAL_DATLAST_PRC(p_COD_ORDER => i.ordhe_cod_ord_ordhe,
                                                 P_NUM_ITEM  => i.num_item_ordit,
                                                 p_flg_db    => 0,
                                                 P_flg_ok    => lv_num);
      apps.app_lmp_global_pkg.insert_log_prc(p_fun_nam => 'APP_LMP_CAP_TOT_MODEL_PKG.CHECK_SMP_ORD_DATLAST_PRC',
                                             p_inputs  => i.ordhe_cod_ord_ordhe || ',' ||
                                                          i.num_item_ordit,
                                             p_outputs => '',
                                             p_flg_ok  => 1);
    end loop;
  
    commit;
    --lv_num:= smp_its_send_orders_fun;
    --commit;
  end;
  ------------------------------------------
  procedure run_after_model_prc is
    lv_cod_run      varchar2(15);
    lv_num          number;
    lv_cod_run_tot  varchar2(15);
    lv_cod_run_tot2 varchar2(15);
  begin
    lv_cod_run := APP_LMP_CAP_TOT_MODEL_PKG.ret_in_run_model_fun;
    /*apps.App_Lmp_Cap_Tot_Model_Pkg.insert_model_stat_prc(p_cod_run    => lv_cod_run,
    p_num_module => 3,
    p_num_step   => 7);*/
    begin
      lv_cod_run_tot  := app_lmp_cap_tot_model_pkg.ret_cod_run_cap_tot_fun;
      lv_cod_run_tot2 := app_lmp_cap_tot_model_pkg.CREATE_COD_RUN_TOT_FUN2;
    exception
      when others then
        null;
    end;
  
    begin
      APP_LMP_CAP_TOT_MODEL_PKG.fill_prod_datlast_report_prc(p_cod_run => lv_cod_run);
      commit;
      /*apps.APP_LMP_CAP_TOT_MODEL_PKG.calculate_heat_plan_prc(p_cod_run => lv_cod_run);
      commit;*/
      APP_LMP_CAP_TOT_MODEL_PKG.fill_balance_report_prc(p_cod_run => lv_cod_run);
      commit;
      --apps.app_lmp_cap_reports_pkg.fill_balance_report_prc(p_cod_run => lv_cod_run);
      --commit;
      app_lmp_cap_reports_pkg.fill_plan_act_cod_run_prc(p_cod_run => lv_cod_run);
      --app_lmp_cap_reports_pkg.get_round_plan_prc(p_cod_run => lv_cod_run);
      commit;
      --apps.APP_LMP_CAP_TOT_MODEL_PKG.fill_inv_report_prc(p_cod_run => lv_cod_run);
      app_lmp_cap_reports_pkg.upd_hsm_daybyday_prc(p_cod_run => lv_cod_run);
    
      update lmp_bas_run_histories th
         set th.flg_in_run_rnhis = 0
       where th.cod_run_rnhis = lv_cod_run
         and th.num_module_rnhis = 3;
    
      /* APPS.APP_LMP_CAP_TOT_MODEL_PKG.update_model_stat_prc(p_cod_run    => lv_cod_run,
      p_num_module => 3,
      p_num_step   => 7,
      p_flg_ok     => 1,
      p_des_error  => NULL);*/
     /* update lmp_bas_run_histories m
         set m.sta_run_rnhis    = 1,
             m.DES_STATUS_RNHIS = 'SUCCEED',
             m.sta_cnfrm_rnhis  = 1
       where m.cod_run_rnhis = lv_cod_run;*/
      app_lmp_cap_tot_model_pkg.update_model_stat_step_prc(p_cod_run     => lv_cod_run_tot,
                                                           p_cod_mjl_run => lv_cod_run,
                                                           p_num_step    => 5,
                                                           P_NUM_MODULE  => 3,
                                                           p_flg_stat    => 1);
    exception
      when others then
        app_lmp_cap_tot_model_pkg.update_model_stat_step_prc(p_cod_run     => lv_cod_run_tot,
                                                             p_cod_mjl_run => lv_cod_run,
                                                             p_num_step    => 5,
                                                             P_NUM_MODULE  => 3,
                                                             p_flg_stat    => 2);
        return;
    end;
    commit;
    --delete from tpin_mis.lmp_tab_1_host5;
    -- apps.APP_LMP_CAP_TOT_MODEL_PKG.insert_ord_pririty_mis_prc(p_cod_run => lv_cod_run);
    --lv_num := tpin_mis.tpin_mis_issuite_to_mis.Get_Request(p_Metadata_Id => 70);
    --commit;
  end;
  --------------------------------------------
  function ret_start_dat_run_fun return date DETERMINISTIC is
    lv_dat date;
  begin
    select h.dat_strt_hrzn_rnhis
      into lv_dat
      from lmp.lmp_bas_run_histories h
     where h.cod_run_rnhis = APP_LMP_CAP_TOT_MODEL_PKG.get_last_cod_run_fun
       and h.num_module_rnhis = 3;
    return lv_dat;
  end;
  --------------------------------------------
  function ret_end_dat_run_fun return date DETERMINISTIC is
    lv_dat date;
  begin
    select h.dat_end_hrzn_rnhis
      into lv_dat
      from lmp.lmp_bas_run_histories h
     where h.cod_run_rnhis = APP_LMP_CAP_TOT_MODEL_PKG.get_last_cod_run_fun
       and h.num_module_rnhis = 3;
    return lv_dat;
  end;
  ---------------------------------------------
  function run_cap_model_fun(p_cod_run           in varchar2,
                             p_connection_server in varchar2,
                             p_identifierName    in varchar2) return number is
    lv_envelope clob;
    lv_xml      xmltype;
    lv_output   varchar2(10000);
    --lv_identifierName varchar2(30);
  begin
    /*select sys_context('userenv', 'client_identifier')
    into lv_identifierName
    from dual;*/
  
    lv_envelope := '<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tem="http://tempuri.org/">
   <soapenv:Header/>
   <soapenv:Body>
      <tem:ExecuteModel>
         <tem:codRun>' || p_cod_run ||
                   '</tem:codRun>
         <tem:connectionServer>' || p_connection_server ||
                   '</tem:connectionServer>
         <tem:identifierName>' || p_identifierName ||
                   '</tem:identifierName>
      </tem:ExecuteModel>
   </soapenv:Body>
</soapenv:Envelope>';
  
    fnd.fnd_call_soap_web_srv_prc(CONTENT   => lv_envelope,
                                  URL       => 'http://services.msc.ir/osb/LMPCAP/CapacityPlanningService/ExecuteModel',
                                  P_OUT_PUT => lv_output);
    /*lv_xml := fnd.fnd_call_ws_fun(p_url_address => 'http://eis.msc.ir/osb/Project_LMPMODEL_LMPADF/Proxy_LMPMODEL_LMPADF_CAPACITY?wsdl',
    p_action      => 'http://eis.msc.ir/osb/Project_LMPMODEL_LMPADF/Proxy_LMPMODEL_LMPADF_CAPACITY/ExecuteModel',
    p_envelope    => lv_envelope);*/
    app_lmp_global_pkg.insert_log_prc(p_fun_nam   => 'APP_LMP_SOP_MODEL_PKG.RUN_SOP_MODEL_FUN',
                                      p_inputs    => 'fnd_call_soap_web_srv_prc is ended',
                                      p_outputs   => to_char(sysdate,
                                                             'YYYYMMDD'),
                                      p_flg_ok    => 1,
                                      p_des_error => lv_output);
    return 1;
  exception
    when others then
      return 0;
  end;

  ---------------------------------------------// s.boosaiedi 13980903 update webservice address
  function run_cap_model2_fun(p_cod_run           in varchar2,
                              p_connection_server in varchar2,
                              p_identifierName    in varchar2) return number is
    lv_envelope clob;
    lv_xml      xmltype;
    --lv_identifierName varchar2(30);
  begin
    /*select sys_context('userenv', 'client_identifier')
    into lv_identifierName
    from dual;*/
  
    /*    lv_envelope := '<?xml version="1.0" encoding="UTF-8"?>
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tem="http://tempuri.org/">
       <soapenv:Header/>
       <soapenv:Body>
          <tem:ExecuteModel>
             <tem:codRun>' || p_cod_run ||
                       '</tem:codRun>
             <tem:connectionServer>' || p_connection_server ||
                       '</tem:connectionServer>
             <tem:identifierName>' || p_identifierName ||
                       '</tem:identifierName>
          </tem:ExecuteModel>
       </soapenv:Body>
    </soapenv:Envelope>';*/
  
    lv_envelope := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
<soap:Header xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
</soap:Header>
<soapenv:Body>
<tem:ExecuteModel xmlns:tem="http://tempuri.org/">    
    <tem:codRun>CAP1399040704</tem:codRun>    
    <tem:connectionServer>PROD</tem:connectionServer>    
    <tem:identifierName>1</tem:identifierName>
</tem:ExecuteModel>
</soapenv:Body>
</soapenv:Envelope>
';
  
    /*lv_envelope:='<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tem="http://tempuri.org/">
       <soapenv:Header/>
       <soapenv:Body>
          <tem:ExecuteModel>
               <!--Optional:-->
        <tem:codRun>CAP1399040704</tem:codRun>
        <!--Optional:-->
        <tem:connectionServer>PROD</tem:connectionServer>
        <!--Optional:-->
        <tem:identifierName>1</tem:identifierName>
          </tem:ExecuteModel>
       </soapenv:Body>
    </soapenv:Envelope>';*/
  
    API_MAS_MODELS_PKG.INS_CLOB_Prc('LMP CAP', lv_envelope, 39089, lv_xml);
  
    lv_xml := fnd.fnd_call_ws_fun(p_url_address => 'http://services.msc.ir/osb/LMPCAP/CapacityPlanningService?wsdl',
                                  p_action      => 'http://services.msc.ir/osb/LMPCAP/CapacityPlanningService/ExecuteModel',
                                  p_envelope    => lv_envelope);
  
    API_MAS_MODELS_PKG.INS_CLOB_Prc('LMP CAP', '', 39089, lv_xml);
    return 1;
  exception
    when others then
      return 0;
  end;
  ----------------------------------//created by s.saeidi
  function ret_last_cod_run_fun return varchar2 deterministic is
    lv_cod_run varchar2(15);
  begin
    select max(th.cod_run_rnhis)
      into lv_cod_run
      from lmp.lmp_bas_run_histories th
     where th.num_module_rnhis = 3
       and th.sta_cnfrm_rnhis = 1;
    return lv_cod_run;
  end;

  ----------------------------------//created by s.saeidi 13991002
  function ret_last_cod_run2_fun return varchar2 deterministic is
    lv_cod_run varchar2(15);
  begin
    select max(th.cod_run_rnhis)
      into lv_cod_run
      from lmp.lmp_bas_run_histories th
     where th.num_module_rnhis = 3;
    return lv_cod_run;
  end;
  ----------------------------------
  function ret_in_run_model_fun return varchar2 deterministic is
    lv_cod_run varchar2(15);
  begin
    select max(th.cod_run_rnhis)
      into lv_cod_run
      from lmp.lmp_bas_run_histories th
     where th.num_module_rnhis = 3
       and th.FLG_IN_RUN_RNHIS = 1;
    return lv_cod_run;
  end;
  ---------------------------------------
  procedure run_job_after_model_prc(p_cod_run in varchar2) is
    lv_msg varchar2(100);
  begin
    begin
      lv_msg := Fnd.Fnd_Sms_And_Email_Pkg.Send_Non_Adv_Sms_Fun(sys.odciVarchar2List('09131657097',
                                                                                    '09130197615',
                                                                                    '09132886631',
                                                                                    '09131866134',
                                                                                    '09131275584',
                                                                                    '09131027312',
                                                                                    '09137946966',
                                                                                    '09137374177',
                                                                                    '09359721908'),
                                                               p_Messagebodies => 'CAP model is done:' ||
                                                                                  p_cod_run ||
                                                                                  ' : ' ||
                                                                                  to_char(sysdate,
                                                                                          'MM/DD HH24:MI'));
    exception
      when others then
        null;
    end;
    dbms_scheduler.run_job(job_name            => 'LMP_JOB_114509',
                           use_current_session => false);
  end;
  -------------------------------------
  procedure run_model_prc is
    lv_cod_run           varchar2(15);
    lv_connection_server varchar2(30);
    lv_string            varchar2(1000);
    lv_num               number := 1;
    lv_msg               varchar2(1000);
    lv_msg_assinment     varchar2(1000);
    lv_msg_SMP           varchar2(1000);
    lv_msg1              varchar2(1000);
    lv_msg_error         varchar2(1000);
    lv_cod_run_tot       varchar2(15);
  begin
  
    app_lmp_global_pkg.insert_log_prc(p_fun_nam   => 'LMP_JOB_98297 IS STARTED',
                                      p_inputs    => to_char(sysdate,
                                                             'YYYYMMDD'),
                                      p_outputs   => to_char(sysdate,
                                                             'YYYYMMDD'),
                                      p_flg_ok    => 1,
                                      p_des_error => '');
  
    begin
      /*BEGIN
        UPDATE LMP.lmp_bas_model_run_stats R
           SET R.DAT_START_MOSTA = NULL,
               R.DAT_END_MOSTA   = NULL,
               R.STA_STEP_MOSTA  = NULL
         where R.cod_run_mosta IN ('AAS', 'AAS_SMP', 'CREATE_ORDER');
      EXCEPTION
        WHEN others then
          null;
      end;
      commit;*/
      begin
        lv_cod_run_tot := app_lmp_cap_tot_model_pkg.CREATE_COD_RUN_TOT_FUN;
      exception
        when others then
          null;
      end;
    
      begin
        app_lmp_cap_tot_model_pkg.insert_model_stat_step_prc(p_cod_run => lv_cod_run_tot);
      exception
        when others then
          null;
      end;
    
      -----assignment
      API_MAS_MODELS_SCH_PKG.Run_Both_Sch_MDL_PRC;
      --brl_mas_ass_mdl_pkg.Run_For_Lmp_prc;
    exception
      when others then
        app_lmp_global_pkg.insert_log_prc(p_fun_nam   => 'api_mas_pkg.Run_AAS_Assignment_Slt_Fun',
                                          p_inputs    => to_char(sysdate,
                                                                 'YYYYMMDD'),
                                          p_outputs   => to_char(sysdate,
                                                                 'YYYYMMDD'),
                                          p_flg_ok    => 0,
                                          p_des_error => 'In Assignmnt Model');
        begin
          lv_msg := Fnd.Fnd_Sms_And_Email_Pkg.Send_Non_Adv_Sms_Fun(sys.odciVarchar2List('09131657097',
                                                                                        '09131275584',
                                                                                        '09132886631',
                                                                                        '09133288076',
                                                                                        '09131866134',
                                                                                        '09130197615',
                                                                                        '09131027312',
                                                                                        '09130197615',
                                                                                        '09133838913',
                                                                                        '09137946966',
                                                                                        '09137374177',
                                                                                        '09359721908'),
                                                                   p_Messagebodies => 'Error in Assignment:' ||
                                                                                      to_char(sysdate,
                                                                                              'MM/DD HH24:MI'));
        exception
          when others then
            null;
        end;
        return;
    end;
  
     BEGIN
      select fp.val_att3_lmpfp
        into lv_msg_error
        from lmp.lmp_bas_fix_params fp
       where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
         and fp.val_att1_lmpfp = 4;
    
      select t.sta_step_mosta
        into lv_msg_SMP
        from lmp.lmp_bas_model_run_stats t
       where t.cod_run_mosta = lv_cod_run_tot
         and t.num_module_mosta = 15;
    exception
      when others then
        null;
    end;
    
    begin
      select t.sta_step_mosta
        into lv_msg_assinment
        from lmp.lmp_bas_model_run_stats t
       where t.cod_run_mosta = lv_cod_run_tot
         and t.num_module_mosta = 10;
    
    exception
      when others then
        lv_msg_assinment := lv_msg_error;
    end;
    
    begin
      IF ((lv_msg_assinment = lv_msg_error or lv_msg_assinment is null) or lv_msg_SMP = lv_msg_error) Then
        app_lmp_global_pkg.insert_log_prc(p_fun_nam   => 'api_mas_pkg.Run_AAS_Assignment_Slt_Fun',
                                          p_inputs    => to_char(sysdate,
                                                                 'YYYYMMDD'),
                                          p_outputs   => to_char(sysdate,
                                                                 'YYYYMMDD'),
                                          p_flg_ok    => 0,
                                          p_des_error => 'In Assignmnt Model');
                                          
        begin
          lv_msg := Fnd.Fnd_Sms_And_Email_Pkg.Send_Non_Adv_Sms_Fun(sys.odciVarchar2List('09131657097',
                                                                                        '09131275584',
                                                                                        '09132886631',
                                                                                        '09133288076',
                                                                                        '09131866134',
                                                                                        '09130197615',
                                                                                        '09131027312',
                                                                                        '09130197615',
                                                                                        '09133838913',
                                                                                        '09137946966',
                                                                                        '09359721908'),
                                                                   p_Messagebodies => 'Error in Assignment:' ||
                                                                                      to_char(sysdate,
                                                                                              'MM/DD HH24:MI'));
        exception
          when others then
            null;
        end;
        RETURN;
      END IF;
    exception
      when others then
        null;
    end;
    
    app_lmp_global_pkg.insert_log_prc(p_fun_nam   => 'api_mas_pkg.Run_AAS_Assignment_Slt_Fun',
                                      p_inputs    => '',
                                      p_outputs   => to_char(lv_num),
                                      p_flg_ok    => 1,
                                      p_des_error => lv_string);
    
    begin
      lv_msg := Fnd.Fnd_Sms_And_Email_Pkg.Send_Non_Adv_Sms_Fun(sys.odciVarchar2List('09131657097',
                                                                                    '09131275584',
                                                                                    '09131866134',
                                                                                    '09132886631',
                                                                                    '09130197615',
                                                                                    '09133838913',
                                                                                    '09137946966',
                                                                                    '09359721908'),
                                                               p_Messagebodies => 'Assignment Models are finished:' ||
                                                                                  to_char(sysdate,
                                                                                          'MM/DD HH24:MI'));
    exception
      when others then
        null;
    end;
    --MAS_MODEL_START
    app_lmp_global_pkg.insert_log_prc(p_fun_nam   => 'MAS_MODEL_START',
                                      p_inputs    => '',
                                      p_outputs   => 'DONE',
                                      p_flg_ok    => 1,
                                      p_des_error => null);
    commit;
  
    --lv_num := api_mas_models_pkg.Run_Mas_OFO_Cap_Model_Fun;
    lv_num := api_mas_models_pkg.Run_Mas_OFO_Cap_Model_Fun2;
    if lv_num = 1 then
      begin
        /*lv_msg := Fnd.Fnd_Sms_And_Email_Pkg.Send_Non_Adv_Sms_Fun(sys.odciVarchar2List('09131657097',
                             '09132324092',
                             '09131027312',
                             '09130197615'),
        p_Messagebodies => 'MAS Model is finished Successfully:' \*try ' || cnt ||'*\
                           ||
                           to_char(sysdate,
                                   'MM/DD HH24:MI'));*/
        lv_msg := Fnd.Fnd_Sms_And_Email_Pkg.Send_Non_Adv_Sms_Fun(sys.odciVarchar2List('09131657097',
                                                                                      '09132324092',
                                                                                      '09131027312',
                                                                                      '09130197615',
                                                                                      '09137946966',
                                                                                      '09137374177',
                                                                                      '09359721908'),
                                                                 p_Messagebodies => 'MAS Model is finished Successfully:' ||
                                                                                    to_char(sysdate,
                                                                                            'MM/DD HH24:MI'));
      exception
        when others then
          null;
      end;
    else
      begin
        lv_msg := Fnd.Fnd_Sms_And_Email_Pkg.Send_Non_Adv_Sms_Fun(sys.odciVarchar2List('09131657097',
                                                                                      '09132324092',
                                                                                      '09130197615',
                                                                                      '09132886631',
                                                                                      '09131027312',
                                                                                      '09132081148',
                                                                                      '09130197615',
                                                                                      '09137946966',
                                                                                      '09137374177',
                                                                                      '09359721908'),
                                                                 p_Messagebodies => 'MAS Model has Error!' /* try ' || cnt*/
                                                                                    ||
                                                                                    ' Please follow it.' ||
                                                                                    to_char(sysdate,
                                                                                            'MM/DD HH24:MI'));
      exception
        when others then
          null;
      end;
      return;
    end if;
  
    app_lmp_global_pkg.insert_log_prc(p_fun_nam   => 'MAS_MODEL_END',
                                      p_inputs    => '',
                                      p_outputs   => 'DONE',
                                      p_flg_ok    => 1,
                                      p_des_error => null);
    commit;
  
    --create virtual orders
    BEGIN
    
      /*app_lmp_cap_tot_model_pkg.update_model_stat_prc(p_cod_run    => 'CREATE_ORDER',
      p_num_module => NULL,
      p_num_step   => 3,
      p_flg_ok     => 0,
      p_des_error  => NULL);*/
      app_lmp_cap_tot_model_pkg.update_model_stat_step_prc(p_cod_run     => lv_cod_run_tot,
                                                           p_cod_mjl_run => '',
                                                           p_num_step    => 3,
                                                           P_NUM_MODULE  => 30,
                                                           p_flg_stat    => 0);
     <<create_virtual_orders>>
     <<IGNORE_FOR_NOW>>
      app_lmp_sop_model_pkg.create_order_info_tot_prc;
      app_lmp_sop_model_pkg.create_virtual_order_prc;
   

      app_lmp_global_pkg.insert_log_prc(p_fun_nam   => 'End_Create_Order',
                                        p_inputs    => '',
                                        p_outputs   => to_char(sysdate,
                                                               'YYYYMMDD'),
                                        p_flg_ok    => 1,
                                        p_des_error => null);
    
      app_lmp_cap_tot_model_pkg.update_model_stat_step_prc(p_cod_run     => lv_cod_run_tot,
                                                           p_cod_mjl_run => '',
                                                           p_num_step    => 3,
                                                           P_NUM_MODULE  => 30,
                                                           p_flg_stat    => 1);
      /*app_lmp_cap_tot_model_pkg.update_model_stat_prc(p_cod_run    => 'CREATE_ORDER',
      p_num_module => NULL,
      p_num_step   => 3,
      p_flg_ok     => 1,
      p_des_error  => NULL);*/
      
       
    exception
      when others then
        null;
        BEGIN
          /*app_lmp_cap_tot_model_pkg.update_model_stat_prc(p_cod_run    => 'CREATE_ORDER',
          p_num_module => NULL,
          p_num_step   => 3,
          p_flg_ok     => 2,
          p_des_error  => NULL);*/
        
          app_lmp_cap_tot_model_pkg.update_model_stat_step_prc(p_cod_run     => lv_cod_run_tot,
                                                               p_cod_mjl_run => '',
                                                               p_num_step    => 3,
                                                               P_NUM_MODULE  => 30,
                                                               p_flg_stat    => 2);
        
          lv_msg := Fnd.Fnd_Sms_And_Email_Pkg.Send_Non_Adv_Sms_Fun(sys.odciVarchar2List('09130197615',
                                                                                        '09137946966',
                                                                                        '09359721908'),
                                                                   p_Messagebodies => 'create orders has Error!' ||
                                                                                      ' Please follow it.' ||
                                                                                      to_char(sysdate,
                                                                                              'MM/DD HH24:MI'));
        exception
          when others then
            null;
        end;
        return;
    END;
    --end;
    commit;
  <<CREATE_CODE_RUN>>
    --create cod_run
    lv_cod_run := APP_LMP_CAP_TOT_MODEL_PKG.CREATE_COD_RUN_FUN(p_dat_start => trunc(sysdate),
                                                               P_dat_end   => trunc(sysdate + 29 + 30),
                                                               p_des       => 'Scheduled ' ||
                                                                              to_char(sysdate,
                                                                                      'YYYY-MM-DD hh:mi:ss'));
  
    begin
    --OUR CSHARP PROGRAM USE OUTPUT OF THIS FUNCTION
      APP_LMP_CAP_TOT_MODEL_PKG.create_model_data_prc(p_cod_run => lv_cod_run);
    exception
      when others then
        null;
        BEGIN
          app_lmp_cap_tot_model_pkg.update_model_stat_step_prc(p_cod_run     => lv_cod_run_tot,
                                                               p_cod_mjl_run => '',
                                                               p_num_step    => 1,
                                                               P_NUM_MODULE  => 3,
                                                               p_flg_stat    => 2);
        
          lv_msg := Fnd.Fnd_Sms_And_Email_Pkg.Send_Non_Adv_Sms_Fun(sys.odciVarchar2List('09130197615',
                                                                                        '09137946966',
                                                                                        '09359721908'),
                                                                   p_Messagebodies => 'create orders has Error!' ||
                                                                                      ' Please follow it.' ||
                                                                                      to_char(sysdate,
                                                                                              'MM/DD HH24:MI'));
        exception
          when others then
            null;
        end;
        return;
    END;
    dbms_output.put_line(lv_cod_run);
    -----
    delete from LMP.LMP_CAP_DBD_INPUTS t
     where t.lkp_typ_dbdin = 'FIX_TON_DAY'
       and cod_run_dbdin = lv_cod_run
       and t.statn_bas_station_id is null;
    --lv_cod_run:='CAP1397061401';
    commit;
  
    begin
      lv_msg := Fnd.Fnd_Sms_And_Email_Pkg.Send_Non_Adv_Sms_Fun(sys.odciVarchar2List('09131657097',
                                                                                    '09130197615',
                                                                                    '09137946966',
                                                                                    '09359721908'),
                                                               p_Messagebodies => 'DONE' ||
                                                                                  ' : ' ||
                                                                                  to_char(sysdate,
                                                                                          'MM/DD HH24:MI'));
    exception
      when others then
        null;
    end;
    --Dbms_lock.sleep(60);
    select name into lv_connection_server from v$database;
    for i in 1 .. 20 loop
      lv_num := APP_LMP_CAP_TOT_MODEL_PKG.run_cap_model_fun(p_cod_run           => lv_cod_run,
                                                            p_connection_server => lv_connection_server,
                                                            p_identifierName    => '1');
      Dbms_lock.sleep(60);
      select rh.sta_run_rnhis
        into lv_num
        from lmp.lmp_bas_run_histories rh
       where rh.cod_run_rnhis = lv_cod_run;
      if lv_num in (2, 3) then
        begin
          app_lmp_sop_model_pkg.check_run_sop_model_prc;
        exception
          when others then
            null;
        end;
        exit;
      end if;
    end loop;
    commit;
  
  end;

  -----------------------------------created by s.boosaiedi 98/05/20
  procedure run_job_model_manual_prc is
  
    lv_cod_run           varchar2(15);
    lv_connection_server varchar2(30);
    lv_string            varchar2(1000);
    lv_num               number := 1;
    lv_msg               varchar2(1000);
    lv_msg_assinment     varchar2(1000);
    lv_msg_SMP           varchar2(1000);
    lv_msg1              varchar2(1000);
    lv_msg_error         varchar2(1000);
    lv_cod_run_tot       varchar2(15);
  begin
  
    app_lmp_global_pkg.insert_log_prc(p_fun_nam   => 'LMP_JOB_98297 IS STARTED',
                                      p_inputs    => to_char(sysdate,
                                                             'YYYYMMDD'),
                                      p_outputs   => to_char(sysdate,
                                                             'YYYYMMDD'),
                                      p_flg_ok    => 1,
                                      p_des_error => '');
  
    begin
      --lv_cod_run_tot := app_lmp_cap_tot_model_pkg.CREATE_COD_RUN_TOT_FUN2;
      lv_cod_run_tot := app_lmp_cap_tot_model_pkg.ret_cod_run_cap_tot_fun;
    exception
      when others then
        null;
    end;
  
    begin
      app_lmp_cap_tot_model_pkg.insert_model_stat_step_prc(p_cod_run => lv_cod_run_tot);
    exception
      when others then
        null;
    end;
    /*begin
      
    -------start assignment
      API_MAS_MODELS_SCH_PKG.Run_Both_Sch_MDL_PRC;
    exception
      when others then
        app_lmp_global_pkg.insert_log_prc(p_fun_nam   => 'api_mas_pkg.Run_AAS_Assignment_Slt_Fun',
                                          p_inputs    => to_char(sysdate,
                                                                 'YYYYMMDD'),
                                          p_outputs   => to_char(sysdate,
                                                                 'YYYYMMDD'),
                                          p_flg_ok    => 0,
                                          p_des_error => 'In Assignmnt Model');
        begin
          lv_msg := Fnd.Fnd_Sms_And_Email_Pkg.Send_Non_Adv_Sms_Fun(sys.odciVarchar2List('09131657097',
                                                                                        '09131275584',
                                                                                        '09132886631',
                                                                                        '09133288076',
                                                                                        '09131866134',
                                                                                        '09130197615',
                                                                                        '09131027312',
                                                                                        '09130197615',
                                                                                        '09133838913',
                                                                                        '09137946966',
                                                                                        '09359721908'),
                                                                   p_Messagebodies => 'Error in Assignment:' ||
                                                                                      to_char(sysdate,
                                                                                              'MM/DD HH24:MI'));
        exception
          when others then
            null;
        end;
        return;
    end;
    
    BEGIN
      select fp.val_att3_lmpfp
        into lv_msg_error
        from lmp.lmp_bas_fix_params fp
       where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
         and fp.val_att1_lmpfp = 4;
    
      select t.sta_step_mosta
        into lv_msg_SMP
        from lmp.lmp_bas_model_run_stats t
       where t.cod_run_mosta = lv_cod_run_tot
         and t.num_module_mosta = 15;
    exception
      when others then
        null;
    end;
    
    begin
      select t.sta_step_mosta
        into lv_msg_assinment
        from lmp.lmp_bas_model_run_stats t
       where t.cod_run_mosta = lv_cod_run_tot
         and t.num_module_mosta = 10;
    
    exception
      when others then
        lv_msg_assinment := lv_msg_error;
    end;
    
    begin
      IF ((lv_msg_assinment = lv_msg_error or lv_msg_assinment is null) or lv_msg_SMP = lv_msg_error) Then
        app_lmp_global_pkg.insert_log_prc(p_fun_nam   => 'api_mas_pkg.Run_AAS_Assignment_Slt_Fun',
                                          p_inputs    => to_char(sysdate,
                                                                 'YYYYMMDD'),
                                          p_outputs   => to_char(sysdate,
                                                                 'YYYYMMDD'),
                                          p_flg_ok    => 0,
                                          p_des_error => 'In Assignmnt Model');
        begin
          lv_msg := Fnd.Fnd_Sms_And_Email_Pkg.Send_Non_Adv_Sms_Fun(sys.odciVarchar2List('09131657097',
                                                                                        '09131275584',
                                                                                        '09132886631',
                                                                                        '09133288076',
                                                                                        '09131866134',
                                                                                        '09130197615',
                                                                                        '09131027312',
                                                                                        '09130197615',
                                                                                        '09133838913',
                                                                                        '09137946966',
                                                                                        '09359721908'),
                                                                   p_Messagebodies => 'Error in Assignment:' ||
                                                                                      to_char(sysdate,
                                                                                              'MM/DD HH24:MI'));
        exception
          when others then
            null;
        end;
        RETURN;
      END IF;
    exception
      when others then
        null;
    end;
    
    app_lmp_global_pkg.insert_log_prc(p_fun_nam   => 'api_mas_pkg.Run_AAS_Assignment_Slt_Fun',
                                      p_inputs    => '',
                                      p_outputs   => to_char(lv_num),
                                      p_flg_ok    => 1,
                                      p_des_error => lv_string);
    
    begin
      lv_msg := Fnd.Fnd_Sms_And_Email_Pkg.Send_Non_Adv_Sms_Fun(sys.odciVarchar2List('09131657097',
                                                                                    '09131275584',
                                                                                    '09131866134',
                                                                                    '09132886631',
                                                                                    '09130197615',
                                                                                    '09133838913',
                                                                                    '09137946966',
                                                                                    '09359721908'),
                                                               p_Messagebodies => 'Assignment Models are finished:' ||
                                                                                  to_char(sysdate,
                                                                                          'MM/DD HH24:MI'));
    exception
      when others then
        null;
    end;*/
    -------end assignment
  
    --MAS_MODEL_START
      app_lmp_global_pkg.insert_log_prc(p_fun_nam   => 'MAS_MODEL_START',
                                        p_inputs    => '',
                                        p_outputs   => 'DONE',
                                        p_flg_ok    => 1,
                                        p_des_error => null);
      commit;
      
      lv_num := api_mas_models_pkg.Run_Mas_OFO_Cap_Model_Fun2;
      if lv_num = 1 then
        begin
          lv_msg := Fnd.Fnd_Sms_And_Email_Pkg.Send_Non_Adv_Sms_Fun(sys.odciVarchar2List('09131657097',
                                                                                        '09132324092',
                                                                                        '09130197615',
                                                                                        '09131027312',
                                                                                        '09130197615',
                                                                                        '09137946966',
                                                                                        '09359721908'),
                                                                   p_Messagebodies => 'MAS Model is finished Successfully:' -- /*/*try ' || cnt ||'*/*/
                                                                                      ||
                                                                                      to_char(sysdate,
                                                                                              'MM/DD HH24:MI'));
        exception
          when others then
            null;
        end;
      else
        begin
          lv_msg := Fnd.Fnd_Sms_And_Email_Pkg.Send_Non_Adv_Sms_Fun(sys.odciVarchar2List('09131657097',
                                                                                        '09132324092',
                                                                                        '09130197615',
                                                                                        '09132886631',
                                                                                        '09131027312',
                                                                                        '09132081148',
                                                                                        '09130197615',
                                                                                        '09137946966',
                                                                                        '09359721908'),
                                                                   p_Messagebodies => 'MAS Model has Error!' /* try ' || cnt*/
                                                                                      ||
                                                                                      ' Please follow it.' ||
                                                                                      to_char(sysdate,
                                                                                              'MM/DD HH24:MI'));
        exception
          when others then
            null;
        end;
        return;
      end if;
      
      app_lmp_global_pkg.insert_log_prc(p_fun_nam   => 'MAS_MODEL_END',
                                        p_inputs    => '',
                                        p_outputs   => 'DONE',
                                        p_flg_ok    => 1,
                                        p_des_error => null);
      commit;
      --MAS_MODEL_end
    
            --create virtual orders start
        BEGIN
        
          app_lmp_cap_tot_model_pkg.update_model_stat_step_prc(p_cod_run     => lv_cod_run_tot,
                                                               p_cod_mjl_run => '',
                                                               p_num_step    => 3,
                                                               P_NUM_MODULE  => 30,
                                                               p_flg_stat    => 0);
          app_lmp_sop_model_pkg.create_order_info_tot_prc;
          app_lmp_sop_model_pkg.create_virtual_order_prc;
        
          app_lmp_global_pkg.insert_log_prc(p_fun_nam   => 'End_Create_Order',
                                            p_inputs    => '',
                                            p_outputs   => to_char(sysdate,
                                                                   'YYYYMMDD'),
                                            p_flg_ok    => 1,
                                            p_des_error => null);
        
          app_lmp_cap_tot_model_pkg.update_model_stat_step_prc(p_cod_run     => lv_cod_run_tot,
                                                               p_cod_mjl_run => '',
                                                               p_num_step    => 3,
                                                               P_NUM_MODULE  => 30,
                                                               p_flg_stat    => 1);
        exception
          when others then
            null;
            BEGIN
            
              app_lmp_cap_tot_model_pkg.update_model_stat_step_prc(p_cod_run     => lv_cod_run_tot,
                                                                   p_cod_mjl_run => '',
                                                                   p_num_step    => 3,
                                                                   P_NUM_MODULE  => 30,
                                                                   p_flg_stat    => 2);
            
              lv_msg := Fnd.Fnd_Sms_And_Email_Pkg.Send_Non_Adv_Sms_Fun(sys.odciVarchar2List('09130197615',
                                                                                          '09137946966',
                                                                                          '09359721908'),
                                                                       p_Messagebodies => 'create orders has Error!' ||
                                                                                          ' Please follow it.' ||
                                                                                          to_char(sysdate,
                                                                                                  'MM/DD HH24:MI'));
            exception
              when others then
                null;
            end;
            return;
        END;
        --end;
        commit;
        --create virtual orders end
      
    
    ---cap model start
    --create cod_run
    lv_cod_run := APP_LMP_CAP_TOT_MODEL_PKG.CREATE_COD_RUN_FUN(p_dat_start => trunc(sysdate),
                                                               P_dat_end   => trunc(sysdate + 29 + 30),
                                                               p_des       => 'Scheduled ' ||
                                                                              to_char(sysdate,
                                                                                      'YYYY-MM-DD hh:mi:ss'));
  
    begin
      APP_LMP_CAP_TOT_MODEL_PKG.create_model_data_prc(p_cod_run => lv_cod_run);
    exception
      when others then
        null;
        BEGIN
          app_lmp_cap_tot_model_pkg.update_model_stat_step_prc(p_cod_run     => lv_cod_run_tot,
                                                               p_cod_mjl_run => '',
                                                               p_num_step    => 1,
                                                               P_NUM_MODULE  => 3,
                                                               p_flg_stat    => 2);
        
          lv_msg := Fnd.Fnd_Sms_And_Email_Pkg.Send_Non_Adv_Sms_Fun(sys.odciVarchar2List('09130197615',
                                                                                        '09137946966',
                                                                                        '09359721908'),
                                                                   p_Messagebodies => 'create orders has Error!' ||
                                                                                      ' Please follow it.' ||
                                                                                      to_char(sysdate,
                                                                                              'MM/DD HH24:MI'));
        exception
          when others then
            null;
        end;
        return;
    END;
    dbms_output.put_line(lv_cod_run);
    -----
    delete from LMP.LMP_CAP_DBD_INPUTS t
     where t.lkp_typ_dbdin = 'FIX_TON_DAY'
       and cod_run_dbdin = lv_cod_run
       and t.statn_bas_station_id is null;
    --lv_cod_run:='CAP1397061401';
    commit;
  
    begin
      lv_msg := Fnd.Fnd_Sms_And_Email_Pkg.Send_Non_Adv_Sms_Fun(sys.odciVarchar2List('09131657097',
                                                                                    '09130197615',
                                                                                    '09137946966',
                                                                                    '09359721908'),
                                                               p_Messagebodies => 'DONE' ||
                                                                                  ' : ' ||
                                                                                  to_char(sysdate,
                                                                                          'MM/DD HH24:MI'));
    exception
      when others then
        null;
    end;
    --Dbms_lock.sleep(60);
    select name into lv_connection_server from v$database;
    for i in 1 .. 2 loop
      lv_num := APP_LMP_CAP_TOT_MODEL_PKG.run_cap_model_fun(p_cod_run           => lv_cod_run,
                                                            p_connection_server => lv_connection_server,
                                                            p_identifierName    => '1');
      Dbms_lock.sleep(60);
      select rh.sta_run_rnhis
        into lv_num
        from lmp.lmp_bas_run_histories rh
       where rh.cod_run_rnhis = lv_cod_run;
      if lv_num in (2, 3) then
        exit;
      end if;
    end loop;
    ---cap model end
    commit;
  
  end;

  ---------------------------
  function get_first_day_month_fun(p_date in date) return date deterministic is
    lv_date date;
  begin
    select min(c.Dat_Calde)
      into lv_date
      from aac_lmp_calendar_viw c
     where c.v_Dat_Calde_In_6 = to_char(p_date, 'YYYYMM');
    return lv_date;
  exception
    when others then
      return trunc(sysdate);
  end;
  -----------------------------
  procedure fill_smp_og_report_prc is
    lv_start_dat      date;
    lv_end_dat        date;
    lv_month          varchar2(6);
    lv_smc_station_id number := 41;
    lv_lkp_typ        varchar2(30) := 'DAYBYDAY_OG';
    lv_end_month      date;
    lv_num_seq        number;
    lv_plan           number;
    lv_act            number;
    lv_typ_item       varchar2(50);
    lv_nam_farsi      varchar2(100);
    lv_nam_prod       varchar2(50);
    lv_nam_header     varchar2(100);
    lv_cod_og         varchar2(10);
  begin
    lv_num_seq := 1000;
    lv_month   := to_char(sysdate, 'YYYYMM');
    select min(c.Dat_Calde) - 1, max(c.Dat_Calde)
      into lv_start_dat, lv_end_month
      from aac_lmp_calendar_viw c
     where c.v_Dat_Calde_In_6 = lv_month;
    lv_end_dat := trunc(sysdate);
  
    delete from lmp.lmp_cap_dbd_reports cdr
     where cdr.lkp_typ_dbdrp = lv_lkp_typ
       and cdr.dat_day_dbdrp between lv_start_dat and lv_end_month
       and cdr.statn_bas_station_id = lv_smc_station_id;
  
    apps.APP_PMS_FOR_SMP_PKG.Set_Date_Prc(lv_start_dat, lv_end_dat);
  
    for d in (select c.Dat_Calde
                from aac_lmp_calendar_viw c
               where c.Dat_Calde between lv_start_dat and lv_end_month
               order by c.Dat_Calde) loop
      ----sum for date
      --plan
      lv_typ_item   := 'PLAN';
      lv_nam_farsi  := 'برنامه';
      lv_nam_prod   := 'جمع';
      lv_nam_header := 'روزانه';
      select sum(t.qty_prod_plan_dayby)
        into lv_plan
        from lmp.lmp_bas_day_by_days t
       where t.statn_bas_station_id in (41, 42, 43, 44)
         and t.dat_day_dayby = d.dat_calde;
      --insert
      lv_num_seq := lv_num_seq + 1;
      insert into lmp.lmp_cap_dbd_reports
        (cap_dbd_report_id,
         typ_item_dbdrp,
         nam_farsi_dbdrp,
         dat_day_dbdrp,
         nam_prod_dbdrp,
         cod_order_group_dbdrp,
         qty_item_dbdrp,
         lkp_typ_dbdrp,
         NUM_SEQ_DBDRP,
         statn_bas_station_id)
      values
        (lmp.lmp_cap_dbd_reports_seq.nextval,
         lv_typ_item,
         lv_nam_farsi,
         d.dat_calde,
         lv_nam_prod,
         null,
         lv_plan,
         lv_lkp_typ,
         lv_num_seq,
         lv_smc_station_id);
    
      --Actual
      lv_typ_item   := 'PROD';
      lv_nam_farsi  := 'عملکرد';
      lv_nam_prod   := 'جمع';
      lv_nam_header := 'روزانه';
    
      select round(sum(tt.WEI_ACTL_PRDST) / 1000)
        into lv_act
        from apps.pms_for_smp_slab_prod_viw tt
       where trunc(tt.DAT_PRODT) = trunc(d.dat_calde);
    
      --insert
      lv_num_seq := lv_num_seq + 1;
      insert into lmp.lmp_cap_dbd_reports
        (cap_dbd_report_id,
         typ_item_dbdrp,
         nam_farsi_dbdrp,
         dat_day_dbdrp,
         nam_prod_dbdrp,
         cod_order_group_dbdrp,
         qty_item_dbdrp,
         lkp_typ_dbdrp,
         NUM_SEQ_DBDRP,
         statn_bas_station_id)
      values
        (lmp.lmp_cap_dbd_reports_seq.nextval,
         lv_typ_item,
         lv_nam_farsi,
         d.dat_calde,
         lv_nam_prod,
         null,
         lv_act,
         lv_lkp_typ,
         lv_num_seq,
         lv_smc_station_id);
    
      --diff
      lv_typ_item   := 'DIFFERENCE';
      lv_nam_farsi  := 'انحراف';
      lv_nam_prod   := 'جمع';
      lv_nam_header := 'روزانه';
      --insert
      lv_num_seq := lv_num_seq + 1;
      insert into lmp.lmp_cap_dbd_reports
        (cap_dbd_report_id,
         typ_item_dbdrp,
         nam_farsi_dbdrp,
         dat_day_dbdrp,
         nam_prod_dbdrp,
         cod_order_group_dbdrp,
         qty_item_dbdrp,
         lkp_typ_dbdrp,
         NUM_SEQ_DBDRP,
         statn_bas_station_id)
      values
        (lmp.lmp_cap_dbd_reports_seq.nextval,
         lv_typ_item,
         lv_nam_farsi,
         d.dat_calde,
         lv_nam_prod,
         null,
         round(nvl(lv_act, 0) - nvl(lv_plan, 0)),
         lv_lkp_typ,
         lv_num_seq,
         lv_smc_station_id);
    
      ----slab for date
      --plan
      lv_typ_item   := 'PLAN';
      lv_nam_farsi  := 'برنامه';
      lv_nam_prod   := 'تختال';
      lv_nam_header := 'روزانه';
      lv_cod_og     := '00';
      select sum(t.qty_prod_plan_dayby)
        into lv_plan
        from lmp.lmp_bas_day_by_days t
       where t.statn_bas_station_id in (41, 42, 43, 44)
         and t.dat_day_dayby = d.dat_calde
         and t.cod_ord_grp_dayby = lv_cod_og;
      --insert
      lv_num_seq := lv_num_seq + 1;
      insert into lmp.lmp_cap_dbd_reports
        (cap_dbd_report_id,
         typ_item_dbdrp,
         nam_farsi_dbdrp,
         dat_day_dbdrp,
         nam_prod_dbdrp,
         cod_order_group_dbdrp,
         qty_item_dbdrp,
         lkp_typ_dbdrp,
         NUM_SEQ_DBDRP,
         statn_bas_station_id)
      values
        (lmp.lmp_cap_dbd_reports_seq.nextval,
         lv_typ_item,
         lv_nam_farsi,
         d.dat_calde,
         lv_nam_prod,
         lv_cod_og,
         lv_plan,
         lv_lkp_typ,
         lv_num_seq,
         lv_smc_station_id);
    
      --Actual
      lv_typ_item   := 'PROD';
      lv_nam_farsi  := 'عملکرد';
      lv_nam_prod   := 'تختال';
      lv_nam_header := 'روزانه';
      lv_cod_og     := '00';
      select round(sum(tt.WEI_ACTL_PRDST) / 1000)
        into lv_act
        from apps.pms_for_smp_slab_prod_viw tt
       where trunc(tt.DAT_PRODT) = trunc(d.dat_calde)
         and lmp_ret_ord_group_for_ord_fun(tt.numorder) = '00';
    
      --insert
      lv_num_seq := lv_num_seq + 1;
      insert into lmp.lmp_cap_dbd_reports
        (cap_dbd_report_id,
         typ_item_dbdrp,
         nam_farsi_dbdrp,
         dat_day_dbdrp,
         nam_prod_dbdrp,
         cod_order_group_dbdrp,
         qty_item_dbdrp,
         lkp_typ_dbdrp,
         NUM_SEQ_DBDRP,
         statn_bas_station_id)
      values
        (lmp.lmp_cap_dbd_reports_seq.nextval,
         lv_typ_item,
         lv_nam_farsi,
         d.dat_calde,
         lv_nam_prod,
         lv_cod_og,
         lv_act,
         lv_lkp_typ,
         lv_num_seq,
         lv_smc_station_id);
    
      --diff
      lv_typ_item   := 'DIFFERENCE';
      lv_nam_farsi  := 'انحراف';
      lv_nam_prod   := 'تختال';
      lv_nam_header := 'روزانه';
      --insert
      lv_num_seq := lv_num_seq + 1;
      insert into lmp.lmp_cap_dbd_reports
        (cap_dbd_report_id,
         typ_item_dbdrp,
         nam_farsi_dbdrp,
         dat_day_dbdrp,
         nam_prod_dbdrp,
         cod_order_group_dbdrp,
         qty_item_dbdrp,
         lkp_typ_dbdrp,
         NUM_SEQ_DBDRP,
         statn_bas_station_id)
      values
        (lmp.lmp_cap_dbd_reports_seq.nextval,
         lv_typ_item,
         lv_nam_farsi,
         d.dat_calde,
         lv_nam_prod,
         lv_cod_og,
         round(nvl(lv_act, 0) - nvl(lv_plan, 0)),
         lv_lkp_typ,
         lv_num_seq,
         lv_smc_station_id);
    
      ---Hot Products
      --sum
      --plan
      lv_typ_item   := 'PLAN';
      lv_nam_farsi  := 'برنامه';
      lv_nam_prod   := 'محصولات گرم';
      lv_nam_header := 'روزانه';
      lv_cod_og     := 'جمع';
    
      select sum(t.qty_prod_plan_dayby)
        into lv_plan
        from lmp.lmp_bas_day_by_days t
       where t.statn_bas_station_id in (41, 42, 43, 44)
         and t.dat_day_dayby = d.dat_calde
         and t.cod_ord_grp_dayby between '01' and '10';
      --insert
      lv_num_seq := lv_num_seq + 1;
      insert into lmp.lmp_cap_dbd_reports
        (cap_dbd_report_id,
         typ_item_dbdrp,
         nam_farsi_dbdrp,
         dat_day_dbdrp,
         nam_prod_dbdrp,
         cod_order_group_dbdrp,
         qty_item_dbdrp,
         lkp_typ_dbdrp,
         NUM_SEQ_DBDRP,
         statn_bas_station_id)
      values
        (lmp.lmp_cap_dbd_reports_seq.nextval,
         lv_typ_item,
         lv_nam_farsi,
         d.dat_calde,
         lv_nam_prod,
         lv_cod_og,
         lv_plan,
         lv_lkp_typ,
         lv_num_seq,
         lv_smc_station_id);
    
      --Actual
      lv_typ_item  := 'PROD';
      lv_nam_farsi := 'عملکرد';
      --lv_nam_prod   := 'محصولات گرم';
      lv_nam_header := 'روزانه';
      --lv_cod_og     := '00';
      select round(sum(tt.WEI_ACTL_PRDST) / 1000)
        into lv_act
        from apps.pms_for_smp_slab_prod_viw tt
       where trunc(tt.DAT_PRODT) = trunc(d.dat_calde)
         and lmp_ret_ord_group_for_ord_fun(tt.numorder) between '01' and '10';
    
      --insert
      lv_num_seq := lv_num_seq + 1;
      insert into lmp.lmp_cap_dbd_reports
        (cap_dbd_report_id,
         typ_item_dbdrp,
         nam_farsi_dbdrp,
         dat_day_dbdrp,
         nam_prod_dbdrp,
         cod_order_group_dbdrp,
         qty_item_dbdrp,
         lkp_typ_dbdrp,
         NUM_SEQ_DBDRP,
         statn_bas_station_id)
      values
        (lmp.lmp_cap_dbd_reports_seq.nextval,
         lv_typ_item,
         lv_nam_farsi,
         d.dat_calde,
         lv_nam_prod,
         lv_cod_og,
         lv_act,
         lv_lkp_typ,
         lv_num_seq,
         lv_smc_station_id);
    
      --diff
      lv_typ_item  := 'DIFFERENCE';
      lv_nam_farsi := 'انحراف';
      --lv_nam_prod   := 'تختال';
      --lv_nam_header := 'روزانه';
      --insert
      lv_num_seq := lv_num_seq + 1;
      insert into lmp.lmp_cap_dbd_reports
        (cap_dbd_report_id,
         typ_item_dbdrp,
         nam_farsi_dbdrp,
         dat_day_dbdrp,
         nam_prod_dbdrp,
         cod_order_group_dbdrp,
         qty_item_dbdrp,
         lkp_typ_dbdrp,
         NUM_SEQ_DBDRP,
         statn_bas_station_id)
      values
        (lmp.lmp_cap_dbd_reports_seq.nextval,
         lv_typ_item,
         lv_nam_farsi,
         d.dat_calde,
         lv_nam_prod,
         lv_cod_og,
         round(nvl(lv_act, 0) - nvl(lv_plan, 0)),
         lv_lkp_typ,
         lv_num_seq,
         lv_smc_station_id);
    
      for og in (select fp.val_att4_lmpfp as cod_og
                   from lmp.lmp_bas_fix_params fp
                  where fp.lkp_typ_lmpfp = 'DAY_BY_DAY'
                    and fp.val_att1_lmpfp = 41
                    and fp.val_att4_lmpfp between '01' and '10') loop
        --plan
        lv_typ_item   := 'PLAN';
        lv_nam_farsi  := 'برنامه';
        lv_nam_prod   := 'محصولات گرم';
        lv_nam_header := 'روزانه';
        lv_cod_og     := og.cod_og;
      
        select sum(t.qty_prod_plan_dayby)
          into lv_plan
          from lmp.lmp_bas_day_by_days t
         where t.statn_bas_station_id in (41, 42, 43, 44)
           and t.dat_day_dayby = d.dat_calde
           and t.cod_ord_grp_dayby = lv_cod_og;
      
        --insert
        lv_num_seq := lv_num_seq + 1;
        insert into lmp.lmp_cap_dbd_reports
          (cap_dbd_report_id,
           typ_item_dbdrp,
           nam_farsi_dbdrp,
           dat_day_dbdrp,
           nam_prod_dbdrp,
           cod_order_group_dbdrp,
           qty_item_dbdrp,
           lkp_typ_dbdrp,
           NUM_SEQ_DBDRP,
           statn_bas_station_id)
        values
          (lmp.lmp_cap_dbd_reports_seq.nextval,
           lv_typ_item,
           lv_nam_farsi,
           d.dat_calde,
           lv_nam_prod,
           lv_cod_og,
           lv_plan,
           lv_lkp_typ,
           lv_num_seq,
           lv_smc_station_id);
      
        --Actual
        lv_typ_item  := 'PROD';
        lv_nam_farsi := 'عملکرد';
        --lv_nam_prod   := 'تختال';
        --lv_nam_header := 'روزانه';
        --lv_cod_og     := '00';
        select round(sum(tt.WEI_ACTL_PRDST) / 1000)
          into lv_act
          from apps.pms_for_smp_slab_prod_viw tt
         where trunc(tt.DAT_PRODT) = trunc(d.dat_calde)
           and lmp_ret_ord_group_for_ord_fun(tt.numorder) = lv_cod_og;
      
        --insert
        lv_num_seq := lv_num_seq + 1;
        insert into lmp.lmp_cap_dbd_reports
          (cap_dbd_report_id,
           typ_item_dbdrp,
           nam_farsi_dbdrp,
           dat_day_dbdrp,
           nam_prod_dbdrp,
           cod_order_group_dbdrp,
           qty_item_dbdrp,
           lkp_typ_dbdrp,
           NUM_SEQ_DBDRP,
           statn_bas_station_id)
        values
          (lmp.lmp_cap_dbd_reports_seq.nextval,
           lv_typ_item,
           lv_nam_farsi,
           d.dat_calde,
           lv_nam_prod,
           lv_cod_og,
           lv_act,
           lv_lkp_typ,
           lv_num_seq,
           lv_smc_station_id);
      
        --diff
        lv_typ_item  := 'DIFFERENCE';
        lv_nam_farsi := 'انحراف';
        --lv_nam_prod   := 'تختال';
        --lv_nam_header := 'روزانه';
        --insert
        lv_num_seq := lv_num_seq + 1;
        insert into lmp.lmp_cap_dbd_reports
          (cap_dbd_report_id,
           typ_item_dbdrp,
           nam_farsi_dbdrp,
           dat_day_dbdrp,
           nam_prod_dbdrp,
           cod_order_group_dbdrp,
           qty_item_dbdrp,
           lkp_typ_dbdrp,
           NUM_SEQ_DBDRP,
           statn_bas_station_id)
        values
          (lmp.lmp_cap_dbd_reports_seq.nextval,
           lv_typ_item,
           lv_nam_farsi,
           d.dat_calde,
           lv_nam_prod,
           lv_cod_og,
           round(nvl(lv_act, 0) - nvl(lv_plan, 0)),
           lv_lkp_typ,
           lv_num_seq,
           lv_smc_station_id);
      end loop;
    
      ---Cold Products
      --sum
      --plan
      lv_typ_item   := 'PLAN';
      lv_nam_farsi  := 'برنامه';
      lv_nam_prod   := 'محصولات سرد';
      lv_nam_header := 'روزانه';
      lv_cod_og     := 'جمع';
    
      select sum(t.qty_prod_plan_dayby)
        into lv_plan
        from lmp.lmp_bas_day_by_days t
       where t.statn_bas_station_id in (41, 42, 43, 44)
         and t.dat_day_dayby = d.dat_calde
         and t.cod_ord_grp_dayby > '10';
      --insert
      lv_num_seq := lv_num_seq + 1;
      insert into lmp.lmp_cap_dbd_reports
        (cap_dbd_report_id,
         typ_item_dbdrp,
         nam_farsi_dbdrp,
         dat_day_dbdrp,
         nam_prod_dbdrp,
         cod_order_group_dbdrp,
         qty_item_dbdrp,
         lkp_typ_dbdrp,
         NUM_SEQ_DBDRP,
         statn_bas_station_id)
      values
        (lmp.lmp_cap_dbd_reports_seq.nextval,
         lv_typ_item,
         lv_nam_farsi,
         d.dat_calde,
         lv_nam_prod,
         lv_cod_og,
         lv_plan,
         lv_lkp_typ,
         lv_num_seq,
         lv_smc_station_id);
    
      --Actual
      lv_typ_item  := 'PROD';
      lv_nam_farsi := 'عملکرد';
      --lv_nam_prod   := 'محصولات گرم';
      lv_nam_header := 'روزانه';
      --lv_cod_og     := '00';
      select round(sum(tt.WEI_ACTL_PRDST) / 1000)
        into lv_act
        from apps.pms_for_smp_slab_prod_viw tt
       where trunc(tt.DAT_PRODT) = trunc(d.dat_calde)
         and lmp_ret_ord_group_for_ord_fun(tt.numorder) > '10';
    
      --insert
      lv_num_seq := lv_num_seq + 1;
      insert into lmp.lmp_cap_dbd_reports
        (cap_dbd_report_id,
         typ_item_dbdrp,
         nam_farsi_dbdrp,
         dat_day_dbdrp,
         nam_prod_dbdrp,
         cod_order_group_dbdrp,
         qty_item_dbdrp,
         lkp_typ_dbdrp,
         NUM_SEQ_DBDRP,
         statn_bas_station_id)
      values
        (lmp.lmp_cap_dbd_reports_seq.nextval,
         lv_typ_item,
         lv_nam_farsi,
         d.dat_calde,
         lv_nam_prod,
         lv_cod_og,
         lv_act,
         lv_lkp_typ,
         lv_num_seq,
         lv_smc_station_id);
    
      --diff
      lv_typ_item  := 'DIFFERENCE';
      lv_nam_farsi := 'انحراف';
      --lv_nam_prod   := 'تختال';
      --lv_nam_header := 'روزانه';
      --insert
      lv_num_seq := lv_num_seq + 1;
      insert into lmp.lmp_cap_dbd_reports
        (cap_dbd_report_id,
         typ_item_dbdrp,
         nam_farsi_dbdrp,
         dat_day_dbdrp,
         nam_prod_dbdrp,
         cod_order_group_dbdrp,
         qty_item_dbdrp,
         lkp_typ_dbdrp,
         NUM_SEQ_DBDRP,
         statn_bas_station_id)
      values
        (lmp.lmp_cap_dbd_reports_seq.nextval,
         lv_typ_item,
         lv_nam_farsi,
         d.dat_calde,
         lv_nam_prod,
         lv_cod_og,
         round(nvl(lv_act, 0) - nvl(lv_plan, 0)),
         lv_lkp_typ,
         lv_num_seq,
         lv_smc_station_id);
    
      for og in (select fp.val_att4_lmpfp as cod_og
                   from lmp.lmp_bas_fix_params fp
                  where fp.lkp_typ_lmpfp = 'DAY_BY_DAY'
                    and fp.val_att1_lmpfp = 41
                    and fp.val_att4_lmpfp > '10') loop
        --plan
        lv_typ_item  := 'PLAN';
        lv_nam_farsi := 'برنامه';
        --lv_nam_prod   := 'محصولات گرم';
        --lv_nam_header := 'روزانه';
        lv_cod_og := og.cod_og;
      
        select sum(t.qty_prod_plan_dayby)
          into lv_plan
          from lmp.lmp_bas_day_by_days t
         where t.statn_bas_station_id in (41, 42, 43, 44)
           and t.dat_day_dayby = d.dat_calde
           and t.cod_ord_grp_dayby = lv_cod_og;
      
        --insert
        lv_num_seq := lv_num_seq + 1;
        insert into lmp.lmp_cap_dbd_reports
          (cap_dbd_report_id,
           typ_item_dbdrp,
           nam_farsi_dbdrp,
           dat_day_dbdrp,
           nam_prod_dbdrp,
           cod_order_group_dbdrp,
           qty_item_dbdrp,
           lkp_typ_dbdrp,
           NUM_SEQ_DBDRP,
           statn_bas_station_id)
        values
          (lmp.lmp_cap_dbd_reports_seq.nextval,
           lv_typ_item,
           lv_nam_farsi,
           d.dat_calde,
           lv_nam_prod,
           lv_cod_og,
           lv_plan,
           lv_lkp_typ,
           lv_num_seq,
           lv_smc_station_id);
      
        --Actual
        lv_typ_item  := 'PROD';
        lv_nam_farsi := 'عملکرد';
        --lv_nam_prod   := 'تختال';
        --lv_nam_header := 'روزانه';
        --lv_cod_og     := '00';
        select round(sum(tt.WEI_ACTL_PRDST) / 1000)
          into lv_act
          from apps.pms_for_smp_slab_prod_viw tt
         where trunc(tt.DAT_PRODT) = trunc(d.dat_calde)
           and lmp_ret_ord_group_for_ord_fun(tt.numorder) = lv_cod_og;
      
        --insert
        lv_num_seq := lv_num_seq + 1;
        insert into lmp.lmp_cap_dbd_reports
          (cap_dbd_report_id,
           typ_item_dbdrp,
           nam_farsi_dbdrp,
           dat_day_dbdrp,
           nam_prod_dbdrp,
           cod_order_group_dbdrp,
           qty_item_dbdrp,
           lkp_typ_dbdrp,
           NUM_SEQ_DBDRP,
           statn_bas_station_id)
        values
          (lmp.lmp_cap_dbd_reports_seq.nextval,
           lv_typ_item,
           lv_nam_farsi,
           d.dat_calde,
           lv_nam_prod,
           lv_cod_og,
           lv_act,
           lv_lkp_typ,
           lv_num_seq,
           lv_smc_station_id);
      
        --diff
        lv_typ_item  := 'DIFFERENCE';
        lv_nam_farsi := 'انحراف';
        --lv_nam_prod   := 'تختال';
        --lv_nam_header := 'روزانه';
        --insert
        lv_num_seq := lv_num_seq + 1;
        insert into lmp.lmp_cap_dbd_reports
          (cap_dbd_report_id,
           typ_item_dbdrp,
           nam_farsi_dbdrp,
           dat_day_dbdrp,
           nam_prod_dbdrp,
           cod_order_group_dbdrp,
           qty_item_dbdrp,
           lkp_typ_dbdrp,
           NUM_SEQ_DBDRP,
           statn_bas_station_id)
        values
          (lmp.lmp_cap_dbd_reports_seq.nextval,
           lv_typ_item,
           lv_nam_farsi,
           d.dat_calde,
           lv_nam_prod,
           lv_cod_og,
           round(nvl(lv_act, 0) - nvl(lv_plan, 0)),
           lv_lkp_typ,
           lv_num_seq,
           lv_smc_station_id);
      end loop;
    
      ----others for date
      --plan
      lv_typ_item   := 'PLAN';
      lv_nam_farsi  := 'برنامه';
      lv_nam_prod   := 'ساير';
      lv_nam_header := 'روزانه';
      lv_cod_og     := null;
      select sum(t.qty_prod_plan_dayby)
        into lv_plan
        from lmp.lmp_bas_day_by_days t
       where t.statn_bas_station_id in (41, 42, 43, 44)
         and t.dat_day_dayby = d.dat_calde
         and t.cod_ord_grp_dayby is null;
      --insert
      lv_num_seq := lv_num_seq + 1;
      insert into lmp.lmp_cap_dbd_reports
        (cap_dbd_report_id,
         typ_item_dbdrp,
         nam_farsi_dbdrp,
         dat_day_dbdrp,
         nam_prod_dbdrp,
         cod_order_group_dbdrp,
         qty_item_dbdrp,
         lkp_typ_dbdrp,
         NUM_SEQ_DBDRP,
         statn_bas_station_id)
      values
        (lmp.lmp_cap_dbd_reports_seq.nextval,
         lv_typ_item,
         lv_nam_farsi,
         d.dat_calde,
         lv_nam_prod,
         lv_cod_og,
         lv_plan,
         lv_lkp_typ,
         lv_num_seq,
         lv_smc_station_id);
    
      --Actual
      lv_typ_item  := 'PROD';
      lv_nam_farsi := 'عملکرد';
      --lv_nam_prod   := 'تختال';
      --lv_nam_header := 'روزانه';
      --lv_cod_og     := '00';
      select round(sum(tt.WEI_ACTL_PRDST) / 1000)
        into lv_act
        from apps.pms_for_smp_slab_prod_viw tt
       where trunc(tt.DAT_PRODT) = trunc(d.dat_calde)
         and tt.numorder is null;
    
      --insert
      lv_num_seq := lv_num_seq + 1;
      insert into lmp.lmp_cap_dbd_reports
        (cap_dbd_report_id,
         typ_item_dbdrp,
         nam_farsi_dbdrp,
         dat_day_dbdrp,
         nam_prod_dbdrp,
         cod_order_group_dbdrp,
         qty_item_dbdrp,
         lkp_typ_dbdrp,
         NUM_SEQ_DBDRP,
         statn_bas_station_id)
      values
        (lmp.lmp_cap_dbd_reports_seq.nextval,
         lv_typ_item,
         lv_nam_farsi,
         d.dat_calde,
         lv_nam_prod,
         lv_cod_og,
         lv_act,
         lv_lkp_typ,
         lv_num_seq,
         lv_smc_station_id);
    
      --diff
      lv_typ_item  := 'DIFFERENCE';
      lv_nam_farsi := 'انحراف';
      --lv_nam_prod   := 'تختال';
      --lv_nam_header := 'روزانه';
      --insert
      lv_num_seq := lv_num_seq + 1;
      insert into lmp.lmp_cap_dbd_reports
        (cap_dbd_report_id,
         typ_item_dbdrp,
         nam_farsi_dbdrp,
         dat_day_dbdrp,
         nam_prod_dbdrp,
         cod_order_group_dbdrp,
         qty_item_dbdrp,
         lkp_typ_dbdrp,
         NUM_SEQ_DBDRP,
         statn_bas_station_id)
      values
        (lmp.lmp_cap_dbd_reports_seq.nextval,
         lv_typ_item,
         lv_nam_farsi,
         d.dat_calde,
         lv_nam_prod,
         lv_cod_og,
         round(nvl(lv_act, 0) - nvl(lv_plan, 0)),
         lv_lkp_typ,
         lv_num_seq,
         lv_smc_station_id);
    
    end loop;
    commit;
  end;
  -------------------------------------
  procedure fill_balance_report_prc(p_cod_run in varchar2) is
    lv_lkp        varchar2(50) := 'CAP_BALANCE';
    lv_start_dat  date;
    lv_end_dat    date;
    lv_first_inv  number;
    lv_last_inv   number;
    lv_num_seq    number;
    lv_production number;
  begin
    delete from lmp.lmp_cap_dbd_reports td
     where td.lkp_typ_dbdrp = lv_lkp
       and td.cod_run_dbdrp = p_cod_run;
  
    select rh.dat_strt_hrzn_rnhis, rh.dat_end_hrzn_rnhis
      into lv_start_dat, lv_end_dat
      from lmp.lmp_bas_run_histories rh
     where rh.cod_run_rnhis = p_cod_run;
    lv_end_dat := lv_start_dat + 32;
  
    for s in (select st.bas_station_id, pa.area_id
                from lmp.lmp_bas_stations st, pms_areas pa
               where st.lkp_group_statn = 'LMP'
                 and st.flg_cap_active_statn = 1
                 and st.area_area_id = pa.area_id) loop
      --tot station order group = null
      select round(sum(im.mu_wei) / 1000)
        into lv_first_inv
        from mas_lmp_initial_mu_viw im, lmp.lmp_bas_orders o
       where im.station_id = s.bas_station_id
         and o.cod_run_lmpor = p_cod_run
            -- and im.cod_run_capin = p_cod_run
         and o.flg_active_in_model_lmpor = 1
         and o.cod_order_lmpor = im.cod_ord_ordhe
         and o.num_order_lmpor = im.num_item_ordit
      --and trunc(im.dat_ent_capin) <= lv_start_dat
      ;
    
      for i in (select c.Dat_Calde
                  from aac_lmp_calendar_viw c
                 where c.Dat_Calde between lv_start_dat and lv_end_dat
                 order by c.Dat_Calde) loop
        --first inventory
        lv_num_seq := 1000;
        insert into lmp.lmp_cap_dbd_reports
          (cap_dbd_report_id,
           typ_item_dbdrp,
           nam_farsi_dbdrp,
           dat_day_dbdrp,
           nam_prod_dbdrp,
           qty_item_dbdrp,
           lkp_typ_dbdrp,
           statn_bas_station_id,
           NUM_SEQ_DBDRP,
           COD_RUN_DBDRP)
        values
          (lmp.lmp_cap_dbd_reports_seq.nextval,
           'FIRST_INV',
           'موجودي ابتداي دوره',
           i.dat_calde,
           null,
           lv_first_inv,
           lv_lkp,
           s.bas_station_id,
           lv_num_seq,
           p_cod_run);
      
        --last inventory
        select round(sum(ip.qty_inventory_invpl))
          into lv_last_inv
          from lmp.lmp_bas_inv_plans ip
         where ip.cod_run_invpl = p_cod_run
           and ip.cod_statn_invpl = s.bas_station_id
           and ip.dat_day_invpl = i.dat_calde;
        lv_num_seq := 9000;
        insert into lmp.lmp_cap_dbd_reports
          (cap_dbd_report_id,
           typ_item_dbdrp,
           nam_farsi_dbdrp,
           dat_day_dbdrp,
           nam_prod_dbdrp,
           qty_item_dbdrp,
           lkp_typ_dbdrp,
           statn_bas_station_id,
           NUM_SEQ_DBDRP,
           COD_RUN_DBDRP)
        values
          (lmp.lmp_cap_dbd_reports_seq.nextval,
           'LAST_INV',
           'موجودي انتهاي دوره',
           i.dat_calde,
           null,
           lv_last_inv,
           lv_lkp,
           s.bas_station_id,
           lv_num_seq,
           p_cod_run);
        lv_first_inv := lv_last_inv;
      
        --recieve
        for j in (select m.bas_station_id,
                         m.seq_sequence_statn,
                         m.nam_ful_far_area,
                         m.Dat_Calde,
                         d.sum_ton
                    from (select ms.bas_station_id,
                                 ms.seq_sequence_statn,
                                 ms.nam_ful_far_area,
                                 cal.Dat_Calde
                            from (select distinct st.bas_station_id,
                                                  st.seq_sequence_statn,
                                                  pa.nam_ful_far_area
                                    from lmp.lmp_bas_transport_plans tp,
                                         lmp.lmp_bas_stations        st,
                                         pms_areas                   pa
                                   where tp.cod_run_trapl = p_cod_run
                                     and tp.cod_statn_to_trapl =
                                         s.bas_station_id
                                     and st.bas_station_id =
                                         tp.cod_statn_from_trapl
                                     and st.area_area_id = pa.area_id) ms,
                                 (select distinct c.Dat_Calde
                                    from aac_lmp_calendar_viw c
                                   where c.Dat_Calde = i.dat_calde) cal) m,
                         (select tp.cod_statn_from_trapl,
                                 tp.dat_day_trapl,
                                 round(sum(tp.qty_tranport_trapl)) sum_ton
                            from lmp.lmp_bas_transport_plans tp,
                                 lmp.lmp_bas_stations        st,
                                 pms_areas                   pa
                           where tp.cod_run_trapl = p_cod_run
                             and tp.cod_statn_to_trapl = s.bas_station_id
                             and st.bas_station_id = tp.cod_statn_from_trapl
                             and st.area_area_id = pa.area_id
                           group by tp.cod_statn_from_trapl, tp.dat_day_trapl) d
                   where m.bas_station_id = d.cod_statn_from_trapl(+)
                     and m.Dat_Calde = d.dat_day_trapl(+)
                   order by m.seq_sequence_statn) loop
          lv_num_seq := 2000 + j.seq_sequence_statn;
          insert into lmp.lmp_cap_dbd_reports
            (cap_dbd_report_id,
             typ_item_dbdrp,
             nam_farsi_dbdrp,
             dat_day_dbdrp,
             nam_prod_dbdrp,
             qty_item_dbdrp,
             lkp_typ_dbdrp,
             statn_bas_station_id,
             NUM_SEQ_DBDRP,
             COD_RUN_DBDRP)
          values
            (lmp.lmp_cap_dbd_reports_seq.nextval,
             'RECIEVE',
             'دريافت',
             i.dat_calde,
             j.nam_ful_far_area,
             j.sum_ton,
             lv_lkp,
             s.bas_station_id,
             lv_num_seq,
             p_cod_run);
        end loop;
      
        --production
        select round(t.sum_ton)
          into lv_production
          from (select distinct c.Dat_Calde
                  from aac_lmp_calendar_viw c
                 where c.Dat_Calde = i.dat_calde) cal,
               (select bpf.dat_day_prppf, sum(bpf.qty_prod_prppf) as sum_ton
                  from lmp.lmp_bas_production_plan_pfs bpf
                 where bpf.cod_run_prppf = p_cod_run
                   and bpf.cod_statn_prppf = s.bas_station_id
                 group by bpf.dat_day_prppf) t
         where cal.Dat_Calde = t.dat_day_prppf(+)
           and cal.Dat_Calde = i.dat_calde;
        lv_num_seq := 3000;
        insert into lmp.lmp_cap_dbd_reports
          (cap_dbd_report_id,
           typ_item_dbdrp,
           nam_farsi_dbdrp,
           dat_day_dbdrp,
           nam_prod_dbdrp,
           qty_item_dbdrp,
           lkp_typ_dbdrp,
           statn_bas_station_id,
           NUM_SEQ_DBDRP,
           COD_RUN_DBDRP)
        values
          (lmp.lmp_cap_dbd_reports_seq.nextval,
           'PRODUCTION',
           'توليد',
           i.dat_calde,
           null,
           lv_production,
           lv_lkp,
           s.bas_station_id,
           lv_num_seq,
           p_cod_run);
      
        --Send
        for j in (select m.bas_station_id,
                         m.seq_sequence_statn,
                         m.nam_ful_far_area,
                         m.Dat_Calde,
                         d.sum_ton
                    from (select ms.bas_station_id,
                                 ms.seq_sequence_statn,
                                 ms.nam_ful_far_area,
                                 cal.Dat_Calde
                            from (select distinct st.bas_station_id,
                                                  st.seq_sequence_statn,
                                                  pa.nam_ful_far_area
                                    from lmp.lmp_bas_transport_plans tp,
                                         lmp.lmp_bas_stations        st,
                                         pms_areas                   pa
                                   where tp.cod_run_trapl = p_cod_run
                                     and tp.cod_statn_from_trapl =
                                         s.bas_station_id
                                     and st.bas_station_id =
                                         tp.cod_statn_to_trapl
                                     and st.area_area_id = pa.area_id) ms,
                                 (select distinct c.Dat_Calde
                                    from aac_lmp_calendar_viw c
                                   where c.Dat_Calde = i.dat_calde) cal) m,
                         (select tp.cod_statn_to_trapl,
                                 tp.dat_day_trapl,
                                 round(sum(tp.qty_tranport_trapl)) sum_ton
                            from lmp.lmp_bas_transport_plans tp,
                                 lmp.lmp_bas_stations        st,
                                 pms_areas                   pa
                           where tp.cod_run_trapl = p_cod_run
                             and tp.cod_statn_from_trapl = s.bas_station_id
                             and st.bas_station_id = tp.cod_statn_to_trapl
                             and st.area_area_id = pa.area_id
                           group by tp.cod_statn_to_trapl, tp.dat_day_trapl) d
                   where m.bas_station_id = d.cod_statn_to_trapl(+)
                     and m.Dat_Calde = d.dat_day_trapl(+)
                   order by m.seq_sequence_statn) loop
          lv_num_seq := 4000 + j.seq_sequence_statn;
          insert into lmp.lmp_cap_dbd_reports
            (cap_dbd_report_id,
             typ_item_dbdrp,
             nam_farsi_dbdrp,
             dat_day_dbdrp,
             nam_prod_dbdrp,
             qty_item_dbdrp,
             lkp_typ_dbdrp,
             statn_bas_station_id,
             NUM_SEQ_DBDRP,
             COD_RUN_DBDRP)
          values
            (lmp.lmp_cap_dbd_reports_seq.nextval,
             'SEND',
             'ارسال',
             i.dat_calde,
             j.nam_ful_far_area,
             j.sum_ton,
             lv_lkp,
             s.bas_station_id,
             lv_num_seq,
             p_cod_run);
        
        end loop;
        COMMIT;
      end loop;
    
      --for og
      for og in (select fp.val_att4_lmpfp as cod_og
                   from lmp.lmp_bas_fix_params fp
                  where fp.lkp_typ_lmpfp = 'DAY_BY_DAY'
                    and fp.val_att1_lmpfp = s.bas_station_id) loop
      
        select round(sum(im.mu_wei) / 1000)
          into lv_first_inv
          from mas_lmp_initial_mu_viw im, lmp.lmp_bas_orders o
         where im.station_id = s.bas_station_id
           and o.cod_run_lmpor = p_cod_run
           and o.flg_active_in_model_lmpor = 1
              --and im.cod_run_capin = p_cod_run
           and o.cod_order_lmpor = im.cod_ord_ordhe
           and o.num_order_lmpor = im.num_item_ordit
           and LMP_RET_ORD_GROUP_FOR_ORD_FUN(p_cod_order => o.cod_order_lmpor ||
                                                            lpad(o.num_order_lmpor,
                                                                 3,
                                                                 '0')) =
               og.cod_og
        --and trunc(im.dat_ent_capin) <= lv_start_dat
        --and o.cod_order_group_lmpor = og.cod_og
        ;
      
        for i in (select c.Dat_Calde
                    from aac_lmp_calendar_viw c
                   where c.Dat_Calde between lv_start_dat and lv_end_dat
                   order by c.Dat_Calde) loop
          --first inventory
          lv_num_seq := 1000;
          insert into lmp.lmp_cap_dbd_reports
            (cap_dbd_report_id,
             typ_item_dbdrp,
             nam_farsi_dbdrp,
             dat_day_dbdrp,
             nam_prod_dbdrp,
             qty_item_dbdrp,
             lkp_typ_dbdrp,
             statn_bas_station_id,
             NUM_SEQ_DBDRP,
             COD_RUN_DBDRP,
             COD_ORDER_GROUP_DBDRP)
          values
            (lmp.lmp_cap_dbd_reports_seq.nextval,
             'FIRST_INV',
             'موجودي ابتداي دوره',
             i.dat_calde,
             null,
             lv_first_inv,
             lv_lkp,
             s.bas_station_id,
             lv_num_seq,
             p_cod_run,
             og.cod_og);
        
          --last inventory
          select round(sum(ip.qty_inventory_invpl))
            into lv_last_inv
            from lmp.lmp_bas_inv_plans ip
           where ip.cod_run_invpl = p_cod_run
             and ip.cod_statn_invpl = s.bas_station_id
             and ip.dat_day_invpl = i.dat_calde
             and ip.cod_order_group_invpl = og.cod_og;
          lv_num_seq := 9000;
          insert into lmp.lmp_cap_dbd_reports
            (cap_dbd_report_id,
             typ_item_dbdrp,
             nam_farsi_dbdrp,
             dat_day_dbdrp,
             nam_prod_dbdrp,
             qty_item_dbdrp,
             lkp_typ_dbdrp,
             statn_bas_station_id,
             NUM_SEQ_DBDRP,
             COD_RUN_DBDRP,
             COD_ORDER_GROUP_DBDRP)
          values
            (lmp.lmp_cap_dbd_reports_seq.nextval,
             'LAST_INV',
             'موجودي انتهاي دوره',
             i.dat_calde,
             null,
             lv_last_inv,
             lv_lkp,
             s.bas_station_id,
             lv_num_seq,
             p_cod_run,
             og.cod_og);
          lv_first_inv := lv_last_inv;
        
          --recieve
          for j in (select m.bas_station_id,
                           m.seq_sequence_statn,
                           m.nam_ful_far_area,
                           m.Dat_Calde,
                           d.sum_ton
                      from (select ms.bas_station_id,
                                   ms.seq_sequence_statn,
                                   ms.nam_ful_far_area,
                                   cal.Dat_Calde
                              from (select distinct st.bas_station_id,
                                                    st.seq_sequence_statn,
                                                    pa.nam_ful_far_area
                                      from lmp.lmp_bas_transport_plans tp,
                                           lmp.lmp_bas_stations        st,
                                           pms_areas                   pa
                                     where tp.cod_run_trapl = p_cod_run
                                       and tp.cod_statn_to_trapl =
                                           s.bas_station_id
                                       and st.bas_station_id =
                                           tp.cod_statn_from_trapl
                                       and st.area_area_id = pa.area_id) ms,
                                   (select distinct c.Dat_Calde
                                      from aac_lmp_calendar_viw c
                                     where c.Dat_Calde = i.dat_calde) cal) m,
                           (select tp.cod_statn_from_trapl,
                                   tp.dat_day_trapl,
                                   round(sum(tp.qty_tranport_trapl)) sum_ton
                              from lmp.lmp_bas_transport_plans tp,
                                   lmp.lmp_bas_stations        st,
                                   pms_areas                   pa
                             where tp.cod_run_trapl = p_cod_run
                               and tp.cod_statn_to_trapl = s.bas_station_id
                               and st.bas_station_id =
                                   tp.cod_statn_from_trapl
                               and st.area_area_id = pa.area_id
                               and tp.cod_order_group_trapl = og.cod_og
                             group by tp.cod_statn_from_trapl,
                                      tp.dat_day_trapl) d
                     where m.bas_station_id = d.cod_statn_from_trapl(+)
                       and m.Dat_Calde = d.dat_day_trapl(+)
                     order by m.seq_sequence_statn) loop
            lv_num_seq := 2000 + j.seq_sequence_statn;
            insert into lmp.lmp_cap_dbd_reports
              (cap_dbd_report_id,
               typ_item_dbdrp,
               nam_farsi_dbdrp,
               dat_day_dbdrp,
               nam_prod_dbdrp,
               qty_item_dbdrp,
               lkp_typ_dbdrp,
               statn_bas_station_id,
               NUM_SEQ_DBDRP,
               COD_RUN_DBDRP,
               COD_ORDER_GROUP_DBDRP)
            values
              (lmp.lmp_cap_dbd_reports_seq.nextval,
               'RECIEVE',
               'دريافت',
               i.dat_calde,
               j.nam_ful_far_area,
               j.sum_ton,
               lv_lkp,
               s.bas_station_id,
               lv_num_seq,
               p_cod_run,
               og.cod_og);
          end loop;
        
          --production
          select round(t.sum_ton)
            into lv_production
            from (select distinct c.Dat_Calde
                    from aac_lmp_calendar_viw c
                   where c.Dat_Calde = i.dat_calde) cal,
                 (select bpf.dat_day_prppf,
                         sum(bpf.qty_prod_prppf) as sum_ton
                    from lmp.lmp_bas_production_plan_pfs bpf
                   where bpf.cod_run_prppf = p_cod_run
                     and bpf.cod_statn_prppf = s.bas_station_id
                     and bpf.cod_order_group_prppf = og.cod_og
                   group by bpf.dat_day_prppf) t
           where cal.Dat_Calde = t.dat_day_prppf(+)
             and cal.Dat_Calde = i.dat_calde;
          lv_num_seq := 3000;
          insert into lmp.lmp_cap_dbd_reports
            (cap_dbd_report_id,
             typ_item_dbdrp,
             nam_farsi_dbdrp,
             dat_day_dbdrp,
             nam_prod_dbdrp,
             qty_item_dbdrp,
             lkp_typ_dbdrp,
             statn_bas_station_id,
             NUM_SEQ_DBDRP,
             COD_RUN_DBDRP,
             COD_ORDER_GROUP_DBDRP)
          values
            (lmp.lmp_cap_dbd_reports_seq.nextval,
             'PRODUCTION',
             'توليد',
             i.dat_calde,
             null,
             lv_production,
             lv_lkp,
             s.bas_station_id,
             lv_num_seq,
             p_cod_run,
             og.cod_og);
        
          --Send
          for j in (select m.bas_station_id,
                           m.seq_sequence_statn,
                           m.nam_ful_far_area,
                           m.Dat_Calde,
                           d.sum_ton
                      from (select ms.bas_station_id,
                                   ms.seq_sequence_statn,
                                   ms.nam_ful_far_area,
                                   cal.Dat_Calde
                              from (select distinct st.bas_station_id,
                                                    st.seq_sequence_statn,
                                                    pa.nam_ful_far_area
                                      from lmp.lmp_bas_transport_plans tp,
                                           lmp.lmp_bas_stations        st,
                                           pms_areas                   pa
                                     where tp.cod_run_trapl = p_cod_run
                                       and tp.cod_statn_from_trapl =
                                           s.bas_station_id
                                       and st.bas_station_id =
                                           tp.cod_statn_to_trapl
                                       and st.area_area_id = pa.area_id) ms,
                                   (select distinct c.Dat_Calde
                                      from aac_lmp_calendar_viw c
                                     where c.Dat_Calde = i.dat_calde) cal) m,
                           (select tp.cod_statn_to_trapl,
                                   tp.dat_day_trapl,
                                   round(sum(tp.qty_tranport_trapl)) sum_ton
                              from lmp.lmp_bas_transport_plans tp,
                                   lmp.lmp_bas_stations        st,
                                   pms_areas                   pa
                             where tp.cod_run_trapl = p_cod_run
                               and tp.cod_statn_from_trapl = s.bas_station_id
                               and st.bas_station_id = tp.cod_statn_to_trapl
                               and st.area_area_id = pa.area_id
                               and tp.cod_order_group_trapl = og.cod_og
                             group by tp.cod_statn_to_trapl, tp.dat_day_trapl) d
                     where m.bas_station_id = d.cod_statn_to_trapl(+)
                       and m.Dat_Calde = d.dat_day_trapl(+)
                     order by m.seq_sequence_statn) loop
            lv_num_seq := 4000 + j.seq_sequence_statn;
            insert into lmp.lmp_cap_dbd_reports
              (cap_dbd_report_id,
               typ_item_dbdrp,
               nam_farsi_dbdrp,
               dat_day_dbdrp,
               nam_prod_dbdrp,
               qty_item_dbdrp,
               lkp_typ_dbdrp,
               statn_bas_station_id,
               NUM_SEQ_DBDRP,
               COD_RUN_DBDRP,
               COD_ORDER_GROUP_DBDRP)
            values
              (lmp.lmp_cap_dbd_reports_seq.nextval,
               'SEND',
               'ارسال',
               i.dat_calde,
               j.nam_ful_far_area,
               j.sum_ton,
               lv_lkp,
               s.bas_station_id,
               lv_num_seq,
               p_cod_run,
               og.cod_og);
          
          end loop;
        
        end loop;
        COMMIT;
      end loop;
    
    end loop;
    --commit;
  end;

  -----------------------------------------------------
  procedure edit_transport_prc(p_cod_run in varchar2) is
    lv_start_dat   date;
    lv_end_dat     date;
    lv_qty_rem_sec number;
  begin
    select rh.dat_strt_hrzn_rnhis, rh.dat_end_hrzn_rnhis
      into lv_start_dat, lv_end_dat
      from lmp.lmp_bas_run_histories rh
     where rh.cod_run_rnhis = p_cod_run
       and rh.num_module_rnhis = 3;
  
    for i in (select c.Dat_Calde
                from aac_lmp_calendar_viw c
               where c.Dat_Calde between lv_start_dat and lv_end_dat
               order by c.Dat_Calde) loop
      for og in (select distinct fp.val_att4_lmpfp as cod_og
                   from lmp.lmp_bas_fix_params fp
                  where fp.lkp_typ_lmpfp = 'DAY_BY_DAY'
                    and fp.val_att4_lmpfp between '23' and '31') loop
        for j in (select t.cod_statn_to_trapl,
                         sum(t.qty_tranport_trapl) as qty_ton
                    from lmp.lmp_bas_transport_plans t
                   where t.cod_run_trapl = p_cod_run
                     and t.cod_statn_from_trapl = -1
                     and t.dat_day_trapl = i.dat_calde
                     and t.cod_order_group_trapl = og.cod_og
                   group by t.cod_statn_to_trapl) loop
          lv_qty_rem_sec := j.qty_ton;
          for k in (select t.bas_transport_plan_id,
                           t.dat_day_trapl,
                           t.cod_profm_trapl,
                           t.cod_statn_from_trapl,
                           t.qty_tranport_trapl
                      from lmp.lmp_bas_transport_plans t
                     where t.cod_run_trapl = p_cod_run
                       and t.cod_statn_to_trapl = -2
                       and t.dat_day_trapl <= i.dat_calde
                       and t.cod_order_group_trapl = og.cod_og
                       and t.qty_tranport_trapl > 0) loop
            if lv_qty_rem_sec <= k.qty_tranport_trapl then
            
              update lmp.lmp_bas_transport_plans t
                 set t.qty_tranport_trapl = t.qty_tranport_trapl -
                                            lv_qty_rem_sec
               where t.bas_transport_plan_id = k.bas_transport_plan_id;
              insert into lmp.lmp_bas_transport_plans
                (bas_transport_plan_id,
                 cod_profm_trapl,
                 cod_run_trapl,
                 cod_statn_from_trapl,
                 cod_statn_to_trapl,
                 dat_day_trapl,
                 num_module_trapl,
                 qty_tranport_trapl,
                 cod_order_group_trapl)
              values
                (lmp.lmp_bas_transport_plans_seq.nextval,
                 k.cod_profm_trapl,
                 p_cod_run,
                 k.cod_statn_from_trapl,
                 j.cod_statn_to_trapl,
                 i.dat_calde,
                 3,
                 lv_qty_rem_sec,
                 og.cod_og);
              lv_qty_rem_sec := 0;
            else
              lv_qty_rem_sec := lv_qty_rem_sec - k.qty_tranport_trapl;
              insert into lmp.lmp_bas_transport_plans
                (bas_transport_plan_id,
                 cod_profm_trapl,
                 cod_run_trapl,
                 cod_statn_from_trapl,
                 cod_statn_to_trapl,
                 dat_day_trapl,
                 num_module_trapl,
                 qty_tranport_trapl,
                 cod_order_group_trapl)
              values
                (lmp.lmp_bas_transport_plans_seq.nextval,
                 k.cod_profm_trapl,
                 p_cod_run,
                 k.cod_statn_from_trapl,
                 j.cod_statn_to_trapl,
                 i.dat_calde,
                 3,
                 k.qty_tranport_trapl,
                 og.cod_og);
              update lmp.lmp_bas_transport_plans t
                 set t.qty_tranport_trapl = 0
               where t.bas_transport_plan_id = k.bas_transport_plan_id;
            end if;
            if lv_qty_rem_sec = 0 then
              exit;
            end if;
          end loop;
        end loop;
      end loop;
    end loop;
  end;
  ------------------------------------------------
  procedure insert_start_inv_prc(p_cod_order  in varchar2,
                                 p_num_item   in varchar2,
                                 p_date       in varchar2,
                                 p_station_id in number,
                                 p_cod_run    in varchar2,
                                 p_qty        in number) is
  begin
    insert into lmp.lmp_cap_inventories
      (cap_inventory_id,
       cod_run_capin,
       cod_ord_capin,
       num_item_capin,
       cod_station1_capin,
       dat_ent_capin,
       qty_kg_capin,
       lkp_typ_inv_capin)
    values
      (lmp.lmp_cap_inventories_seq.nextval,
       p_cod_run,
       p_cod_order,
       p_num_item,
       p_station_id,
       to_date(p_date, 'YYYYMMDD', 'nls_calendar=persian'),
       p_qty,
       'START_INV');
  end;
  --------------------------------------------------------// CREATED BY S.SAEIDI 13991104
  --------------------------------------------------------// Edited By Hr.Ebrahimi 14000219 for AAS
  procedure cal_aas_data_viw_prc (p_cod_run in varchar2) is
    lv_act_month         number;
    lv_act_station_month number;
    lv_dat_end_act       date;
    lv_current_month     varchar2(6);
    lv_date              varchar2(30);
    lv_plan_sch          number := 0;
    lv_area_id           number;
    lv_num_seq           number;
    lv_released          number;
    
  begin
  
  -----------------********************** Fill Released Sch
   for o in (select fp.val_att4_lmpfp as cod_og
                 from lmp.lmp_bas_fix_params fp
                where fp.lkp_typ_lmpfp = 'DAY_BY_DAY'
                  and fp.val_att1_lmpfp = 45) loop 
  select nvl(sum(RV.SUM_WEI), 0)
          into lv_released
          from apps.hmp_lmp_release_sch_ord_viw RV
         where  
         lmp_ret_ord_group_for_ord_fun(RV.ORDER_CODE) = o.cod_og
         ;
      
        insert into lmp.lmp_bas_fix_params
          (bas_fix_param_id,
           val_att3_lmpfp,
           lkp_typ_lmpfp,
           val_att2_lmpfp,
           val_att4_lmpfp)
        values
          (lmp.lmp_bas_fix_params_seq.nextval,
           p_cod_run,
           'LAST_PLAN_OG',
           lv_released,
           o.cod_og);
      
   
  end loop;

  
    ----Insert Last Released Plan Data into fixparam
    insert into lmp.lmp_bas_fix_params
      (bas_fix_param_id,
       val_att2_lmpfp,
       val_att3_lmpfp,
       dat_att_lmpfp,
       lkp_typ_lmpfp)
    values
      (lmp.lmp_bas_fix_params_seq.nextval,
       45,
       p_cod_run,
       apps.api_mas_run_simulators_pkg.return_hsm_available_time_fun,
       'LAST_PLAN');
       
       insert into lmp.lmp_bas_fix_params
      (bas_fix_param_id,
       val_att2_lmpfp,
       val_att3_lmpfp,
       dat_att_lmpfp,
       lkp_typ_lmpfp)
    values
      (lmp.lmp_bas_fix_params_seq.nextval,
       45,
       p_cod_run,
       app_hmp_hsm_optimizer_pkg.Calc_Time_Release_Fun,
       'LAST_PLAN_TEST');



  ----------------------************************ Fill Actuals
  
    app_lmp_global_pkg.insert_log_prc(p_fun_nam   => 'cal_actual_aas_prc',
                                      p_inputs    => 'START',
                                      p_outputs   => to_char(sysdate,
                                                             'YYYYMMDD'),
                                      p_flg_ok    => 1,
                                      p_des_error => null);
  
    BEGIN
      delete from lmp.lmp_bas_actual_datas a
       where a.cod_run_lmpad = p_cod_run
         and a.dat_day_lmpad = trunc(sysdate);
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
    lv_dat_end_act   := TRUNC(SYSDATE);
    lv_current_month := to_char(sysdate, 'YYYYMM', 'nls_calendar=persian');
    ---set data hsm
    App_Pms_For_Mas_Pkg.set_param_for_mas_viw_prc(lv_dat_end_act - 1,
                                                  lv_dat_end_act + 1,
                                                  NULL,
                                                  1);
  
    for j in (SELECT T.VAL_ATT1_LMPFP AS PF_ID,
                     T.VAL_ATT4_LMPFP AS COD_PF,
                     T.VAL_ATT3_LMPFP AS COD_OG
                FROM LMP.LMP_BAS_FIX_PARAMS T
               WHERE T.LKP_TYP_LMPFP LIKE 'SOP_OG_PF') loop
      lv_act_month := 0;
      LV_PLAN_SCH  := 0;
      begin
        select nvl(sum(t1.wei_actl_prdst), 0)
          into lv_act_month
          from apps.hsm_lmp_coil_51_produce_viw t1
         where trunc(t1.DAT_REF_PRO_PRDST) >= lv_dat_end_act
           and trunc(t1.DAT_REF_PRO_PRDST) < lv_dat_end_act + 1
           and t1.COD_ORD_GRP_PRDST = j.cod_og;
      exception
        when no_data_found then
          lv_act_month := 0;
      end;
      if lv_act_month > 0 then
        insert into lmp.lmp_bas_actual_datas
          (bas_actual_data_id,
           cod_run_lmpad,
           cod_station_lmpad,
           cod_prod_family_id_lmpad,
           cod_order_group_lmpad,
           val_month_lmpad,
           qty_actual_lmpad,
           dat_day_lmpad)
        values
          (lmp.Lmp_Bas_Actual_Datas_seq.nextval,
           p_cod_run,
           45,
           j.pf_id,
           j.cod_og,
           lv_current_month,
           lv_act_month,
           lv_dat_end_act);
      end if;
    end loop;
    commit;
  
    app_lmp_global_pkg.insert_log_prc(p_fun_nam   => 'CAL_ACTUAL_PROD_PRC',
                                      p_inputs    => 'END',
                                      p_outputs   => to_char(sysdate,
                                                             'YYYYMMDD'),
                                      p_flg_ok    => 1,
                                      p_des_error => null);  
  
  end;
  

  --------------------------------------------- updated by s.boosaiedi 1398/07/28 changed to lmp_sop_target_stations
  procedure cal_target_month_prc(p_cod_run in varchar2) is
    lv_month       varchar2(6);
    lv_start_dat   date;
    lv_end_dat     date;
    lv_plan        number;
    lv_act         number;
    lv_plan_sch    number;
    lv_num_seq     number;
    lv_dat_end_act date;
    lv_max         number;
    lv_min         number;
    lv_targ        number;
    lv_released    number;
         
  begin
    select h.dat_strt_hrzn_rnhis
      into lv_start_dat
      from lmp.lmp_bas_run_histories h
     where h.cod_run_rnhis = p_cod_run;
    lv_dat_end_act := lv_start_dat;
    lv_month       := to_char(lv_start_dat, 'YYYYMM');
    --dbms_output.put_line(lv_month);
    
    select min(c.Dat_Calde)
      into lv_start_dat
      from aac_lmp_calendar_viw c
     where c.v_Dat_Calde_In_6 = lv_month;
     
    lv_end_dat := trunc(sysdate);
    
    lv_num_seq := app_lmp_params_pkg.update_str_date_smp_rep_fun(p_date => lv_start_dat);
    lv_num_seq := app_lmp_params_pkg.update_end_date_smp_rep_fun(p_date => lv_end_dat);
  
    App_Pms_For_Mas_Pkg.set_param_for_mas_viw_prc(lv_start_dat,
                                                  lv_end_dat,
                                                  NULL,
                                                  1);
    apps.APP_PMS_FOR_SMP_PKG.Set_Date_Prc(lv_start_dat, lv_end_dat);
    
    for i in (select ts.qty_plan_lstst,
                     ts.qty_max_lstst,
                     ts.qty_min_lstst,
                     ts.statn_bas_station_id,
                     pa.area_id,
                     pa.arstu_ide_pk_arstu
                from lmp.lmp_sop_target_stations ts,
                     lmp.lmp_bas_stations        st,
                     pms.pms_areas               pa
               where ts.cod_run_cap_lstst = '0'
                 and pa.area_id = st.area_area_id
                 and st.bas_station_id = ts.statn_bas_station_id
                 and ts.lkp_type_lstst = 'CAP_TARGET_STATION'
                 and ts.val_month_lstst = lv_month
                 and (ts.qty_plan_lstst > 0 or ts.qty_max_lstst > 0 or
                     ts.qty_min_lstst > 0)) loop
    
      --smc
      if i.statn_bas_station_id = 41 then
        lv_plan := nvl(i.qty_plan_lstst, 0);
        lv_min  := nvl(i.qty_min_lstst, 0);
        lv_max  := nvl(i.qty_max_lstst, 0);
        select nvl(round(sum(wp.WEI_ACTL_PRODT) / 1000), 0)
          into lv_act
          from PMS_FOR_LMP_WEI_PROD_VIW wp
         where wp.NAM_BRIEF like 'CCM%'
           and wp.DATE_GEN < lv_dat_end_act;
      
        select nvl(round(sum(t1.WEI_ASSIGNED_KG) / 1000), 0)
          into lv_plan_sch
          from apps.mas_lmp_assigned_slab_typ_viw t1
         where t1.NUM_AREA_ID_LOC_AASTH in (161, 160, 162, 163, 7375133);
      
        insert into LMP.LMP_CAP_DBD_INPUTS
          (CAP_DBD_INPUT_ID,
           STATN_BAS_STATION_ID,
           VAL_MONTH_DBDIN,
           LKP_TYP_DBDIN,
           QTY_PLAN_DBDIN,
           QTY_MIN_DBDIN,
           QTY_MAX_DBDIN,
           COD_RUN_DBDIN)
        values
          (lmp.lmp_cap_dbd_inputs_seq.nextval,
           i.statn_bas_station_id,
           lv_month,
           'TOTAL_STATION',
           greatest(lv_plan - (nvl(lv_act, 0) + nvl(lv_plan_sch, 0)), 0),
           greatest(lv_min - (nvl(lv_act, 0) + nvl(lv_plan_sch, 0)), 0),
           greatest(lv_max - (nvl(lv_act, 0) + nvl(lv_plan_sch, 0)), 0),
           p_cod_run);
      end if;
    
      --51
      if i.statn_bas_station_id = 45 then
        lv_plan := nvl(i.qty_plan_lstst, 0);
        lv_min  := nvl(i.qty_min_lstst, 0);
        lv_max  := nvl(i.qty_max_lstst, 0);
        select nvl(sum(t.wei_actl_prdst) / 1000, 0)
          into lv_act
          from apps.hsm_lmp_coil_51_produce_viw t
         where trunc(t.DAT_REF_PRO_PRDST) >= lv_start_dat
           and trunc(t.DAT_REF_PRO_PRDST) < lv_dat_end_act;
        insert into LMP.LMP_CAP_DBD_INPUTS
          (CAP_DBD_INPUT_ID,
           STATN_BAS_STATION_ID,
           VAL_MONTH_DBDIN,
           LKP_TYP_DBDIN,
           QTY_PLAN_DBDIN,
           QTY_MIN_DBDIN,
           QTY_MAX_DBDIN,
           COD_RUN_DBDIN)
        values
          (lmp.lmp_cap_dbd_inputs_seq.nextval,
           i.statn_bas_station_id,
           lv_month,
           'TOTAL_STATION',
           greatest(lv_plan - lv_act -
                    (select sum(rv.SUM_WEI) / 1000
                       from apps.hmp_lmp_release_sch_ord_viw RV),
                    0),   
          -- greatest(lv_plan - lv_act, 0), 
                   
           greatest(lv_min - lv_act, 0),
           greatest(lv_max - lv_act, 0),
           p_cod_run);
      end if;
    
      if i.statn_bas_station_id = 3 then
        lv_plan := nvl(i.qty_plan_lstst, 0);
        lv_min  := nvl(i.qty_min_lstst, 0);
        lv_max  := nvl(i.qty_max_lstst, 0);
      
        select nvl(sum(t.wei_net_prdst) / 1000, 0)
          into lv_act
          from apps.ccm_lmp_accept_coil_viw t
         where trunc(t.DAT_STK_PRDST) >= lv_start_dat
           and trunc(t.DAT_STK_PRDST) < lv_dat_end_act;
      
        insert into LMP.LMP_CAP_DBD_INPUTS
          (CAP_DBD_INPUT_ID,
           STATN_BAS_STATION_ID,
           VAL_MONTH_DBDIN,
           LKP_TYP_DBDIN,
           QTY_PLAN_DBDIN,
           QTY_MIN_DBDIN,
           QTY_MAX_DBDIN,
           COD_RUN_DBDIN)
        values
          (lmp.lmp_cap_dbd_inputs_seq.nextval,
           i.statn_bas_station_id,
           lv_month,
           'TOTAL_STATION',
           greatest(lv_plan - lv_act, 0),
           greatest(lv_min - lv_act, 0),
           greatest(lv_max - lv_act, 0),
           p_cod_run);
      else
        if i.arstu_ide_pk_arstu like 'M.S.C CO/M.S.C/CCM%' then
          lv_plan := nvl(i.qty_plan_lstst, 0);
          lv_min  := nvl(i.qty_min_lstst, 0);
          lv_max  := nvl(i.qty_max_lstst, 0);
        
          select nvl(sum(t.WEI) / 1000, 0) as sum_ton
            into lv_act
            from CCM_FOR_MAS_PROD_VIW t
           where t.AREA_ID = i.area_id
             and t.DAT < lv_dat_end_act;
        
          insert into LMP.LMP_CAP_DBD_INPUTS
            (CAP_DBD_INPUT_ID,
             STATN_BAS_STATION_ID,
             VAL_MONTH_DBDIN,
             LKP_TYP_DBDIN,
             QTY_PLAN_DBDIN,
             QTY_MIN_DBDIN,
             QTY_MAX_DBDIN,
             COD_RUN_DBDIN)
          values
            (lmp.lmp_cap_dbd_inputs_seq.nextval,
             i.statn_bas_station_id,
             lv_month,
             'TOTAL_STATION',
             greatest(lv_plan - lv_act, 0),
             greatest(lv_min - lv_act, 0),
             greatest(lv_max - lv_act, 0),
             p_cod_run);
        end if;
      end if;
    end loop;
  
    --محاسبه گروه سفارش براي خطوط سرد
    for i in (select st.bas_station_id, pa.area_id
                from lmp.lmp_bas_stations st, pms_areas pa
               where pa.area_id = st.area_area_id
                 and pa.arstu_ide_pk_arstu like 'M.S.C CO/M.S.C/CCM%') loop
      for og in (select fp.val_att4_lmpfp as cod_og
                   from lmp.lmp_bas_fix_params fp
                  where fp.lkp_typ_lmpfp = 'DAY_BY_DAY'
                    and fp.val_att1_lmpfp = i.bas_station_id) loop
        select sum(dd.qty_prod_plan_dayby)
          into lv_plan
          from lmp.lmp_bas_day_by_days dd
         where dd.statn_bas_station_id = i.bas_station_id
           and dd.cod_ord_grp_dayby = og.cod_og
           and to_char(dd.dat_day_dayby, 'YYYYMM') = lv_month;
      
        begin
          select ts.qty_plan_lstst, ts.qty_max_lstst, ts.qty_min_lstst
            into lv_targ, lv_max, lv_min
            from lmp.lmp_sop_target_stations ts
           where ts.cod_run_cap_lstst = '0'
             and ts.lkp_type_lstst = 'CAP_TARGET_OG'
             and ts.statn_bas_station_id = i.bas_station_id
             and ts.val_month_lstst = lv_month
             and ts.cod_order_group_lstst = og.COD_OG;
        
        exception
          when others then
            lv_max  := null;
            lv_min  := null;
            lv_targ := null;
        end;
      
        lv_targ := nvl(lv_targ, lv_plan);
        select (sum(t.WEI) / 1000)
          into lv_act
          from CCM_FOR_MAS_PROD_VIW t
         where t.DAT < lv_dat_end_act
           and t.AREA_ID = i.area_id
           and lmp_ret_ord_group_for_ord_fun(p_cod_order => t.ORDIT_ORDHE_COD_ORD_ORDHE ||
                                                            lpad(t.ORDIT_NUM_ITEM_ORDIT,
                                                                 3,
                                                                 '0')) =
               og.cod_og;
        insert into LMP.LMP_CAP_DBD_INPUTS
          (CAP_DBD_INPUT_ID,
           STATN_BAS_STATION_ID,
           VAL_MONTH_DBDIN,
           LKP_TYP_DBDIN,
           QTY_PLAN_DBDIN,
           COD_RUN_DBDIN,
           COD_ORDER_GROUP_DBDIN,
           QTY_max_DBDIN,
           QTY_min_DBDIN)
        values
          (lmp.lmp_cap_dbd_inputs_seq.nextval,
           i.bas_station_id,
           lv_month,
           'TOTAL_STATION_OG',
           greatest(lv_targ - nvl(lv_act, 0), 0),
           p_cod_run,
           og.cod_og,
           greatest(lv_max - nvl(lv_act, 0), 0),
           greatest(lv_min - nvl(lv_act, 0), 0));
        -- end if;
      end loop;
    end loop;
  
    --51 for og
    for og in (select fp.val_att4_lmpfp as cod_og
                 from lmp.lmp_bas_fix_params fp
                where fp.lkp_typ_lmpfp = 'DAY_BY_DAY'
                  and fp.val_att1_lmpfp = 45
                  and fp.val_att4_lmpfp not in ('01')) loop
      select sum(dd.qty_prod_plan_dayby)
        into lv_plan
        from lmp.lmp_bas_day_by_days dd
       where dd.statn_bas_station_id = 45
         and dd.cod_ord_grp_dayby = og.cod_og
         and to_char(dd.dat_day_dayby, 'YYYYMM') = lv_month;
    
      begin
      
        select ts.qty_plan_lstst, ts.qty_max_lstst, ts.qty_min_lstst
          into lv_targ, lv_max, lv_min
          from lmp.lmp_sop_target_stations ts
         where ts.cod_run_cap_lstst = '0'
           and ts.lkp_type_lstst = 'CAP_TARGET_OG'
           and ts.statn_bas_station_id = 45
           and ts.val_month_lstst = lv_month
           and ts.cod_order_group_lstst = og.COD_OG;
      
      exception
        when others then
          lv_max  := null;
          lv_min  := null;
          lv_targ := null;
      end;
    
      select nvl(sum(tt.wei_actl_prdst) / 1000, 0)
        into lv_act
        from apps.hsm_lmp_coil_51_produce_viw tt
       where trunc(tt.DAT_REF_PRO_PRDST) >= lv_start_dat
         and trunc(tt.DAT_REF_PRO_PRDST) < lv_dat_end_act
         and tt.COD_ORD_GRP_PRDST = og.cod_og;
    
      lv_targ := nvl(lv_targ, lv_plan);

      -----------------------  cal actual_aas_prc 1400/01/25
     /*begin
        app_lmp_sop_tot_model_pkg.cal_actual_aas_prc(p_cod_run => p_cod_run);
      exception
        when others then
          null;
      end;*/
      --------------------Considering Released Plans in Targets --Hr.Ebrahimi 1399/09/02
      
        select nvl(sum(RV.SUM_WEI), 0)
          into lv_released
          from apps.hmp_lmp_release_sch_ord_viw RV
         where  /*RV.ORDER_CODE in (select t.ordhe_cod_ord_ordhe ||
               Lpad(t.num_item_ordit, 3, 0)
         from sal.sal_order_items t
         where t.cod_ord_grpg_ordit=og.cod_og)*/
         lmp_ret_ord_group_for_ord_fun(RV.ORDER_CODE) = og.cod_og
         ;
      
      insert into LMP.LMP_CAP_DBD_INPUTS
        (CAP_DBD_INPUT_ID,
         STATN_BAS_STATION_ID,
         VAL_MONTH_DBDIN,
         LKP_TYP_DBDIN,
         QTY_PLAN_DBDIN,
         COD_RUN_DBDIN,
         COD_ORDER_GROUP_DBDIN,
         QTY_max_DBDIN,
         QTY_min_DBDIN)
      values
        (lmp.lmp_cap_dbd_inputs_seq.nextval,
         45,
         lv_month,
         'TOTAL_STATION_OG',
         greatest(lv_targ - nvl(lv_act, 0) - nvl(lv_released / 1000, 0), 0),
         --greatest(lv_targ - nvl(lv_act, 0), 0),
         p_cod_run,
         og.cod_og,
         greatest(lv_max - nvl(lv_act, 0), 0),
         greatest(lv_min - nvl(lv_act, 0), 0));
      -- end if;
    end loop;
  
    /* for j in (select ts.qty_plan_lstst,
                       ts.qty_max_lstst,
                       ts.qty_min_lstst,
                       ts.statn_bas_station_id,
                       pa.area_id,
                       ts.cod_order_group_lstst,
                       pa.arstu_ide_pk_arstu
                  from lmp.lmp_sop_target_stations ts,
                       lmp.lmp_bas_stations        st,
                       pms.pms_areas               pa
                 where ts.cod_run_cap_lstst = '0'
                   and pa.area_id = st.area_area_id
                   and st.bas_station_id = ts.statn_bas_station_id
                   and ts.lkp_type_lstst = 'CAP_TARGET_OG'
                   and ts.val_month_lstst = lv_month
                   and st.bas_station_id = 45
                   and (ts.qty_plan_lstst > 0 or ts.qty_max_lstst > 0 or
                       ts.qty_min_lstst > 0)) loop
        begin
          if j.cod_order_group_lstst >= 21 then
            select sum(dd.qty_prod_plan_dayby)
              into lv_plan
              from lmp.lmp_bas_day_by_days dd
             where dd.statn_bas_station_id = j.statn_bas_station_id
               and dd.cod_ord_grp_dayby = j.cod_order_group_lstst
               and to_char(dd.dat_day_dayby, 'YYYYMM') = lv_month;
          end if;
        exception
          when others then
            lv_plan := null;
        end;
      
        select nvl(sum(tt.wei_actl_prdst) / 1000, 0)
          into lv_act
          from apps.hsm_lmp_coil_51_produce_viw tt
         where trunc(tt.DAT_REF_PRO_PRDST) >= lv_start_dat
           and trunc(tt.DAT_REF_PRO_PRDST) < lv_dat_end_act
           and tt.COD_ORD_GRP_PRDST = j.cod_order_group_lstst;
      
        lv_targ := nvl(j.qty_plan_lstst, lv_plan);
      
        insert into LMP.LMP_CAP_DBD_INPUTS
          (CAP_DBD_INPUT_ID,
           STATN_BAS_STATION_ID,
           VAL_MONTH_DBDIN,
           LKP_TYP_DBDIN,
           QTY_PLAN_DBDIN,
           COD_RUN_DBDIN,
           COD_ORDER_GROUP_DBDIN,
           qty_max_dbdin,
           qty_min_dbdin)
        values
          (lmp.lmp_cap_dbd_inputs_seq.nextval,
           j.statn_bas_station_id,
           lv_month,
           'TOTAL_STATION_OG',
           greatest(lv_targ - lv_act, 0),
           p_cod_run,
           j.cod_order_group_lstst,
           greatest(j.qty_max_lstst - lv_act, 0),
           greatest(j.qty_min_lstst - lv_act, 0));
      end loop;
    */
  
    --محاسبه گروه سفارش براي ريخته گري
    for i in (select st.bas_station_id, pa.area_id
                from lmp.lmp_bas_stations st, pms_areas pa
               where pa.area_id = st.area_area_id
                 and st.bas_station_id = 41) loop
      for og in (select fp.val_att4_lmpfp as cod_og
                   from lmp.lmp_bas_fix_params fp
                  where fp.lkp_typ_lmpfp = 'DAY_BY_DAY'
                    and fp.val_att1_lmpfp = i.bas_station_id) loop
      
        begin
          select ts.qty_plan_lstst, ts.qty_max_lstst, ts.qty_min_lstst
            into lv_targ, lv_max, lv_min
            from lmp.lmp_sop_target_stations ts
           where ts.cod_run_cap_lstst = '0'
             and ts.lkp_type_lstst = 'CAP_TARGET_OG'
             and ts.statn_bas_station_id = i.bas_station_id
             and ts.val_month_lstst = lv_month
             and ts.cod_order_group_lstst = og.COD_OG;
        exception
          when others then
            lv_max  := null;
            lv_min  := null;
            lv_targ := null;
        end;
      
        if nvl(lv_max, 0) + nvl(lv_targ, 0) + nvl(lv_min, 0) = 0 then
          continue;
        end if;
      
        select round(sum(tt.WEI_ACTL_PRDST) / 1000)
          into lv_act
          from apps.pms_for_smp_slab_prod_viw tt
         where lmp_ret_ord_group_for_ord_fun(tt.numorder) = og.cod_og;
      
        insert into LMP.LMP_CAP_DBD_INPUTS
          (CAP_DBD_INPUT_ID,
           STATN_BAS_STATION_ID,
           VAL_MONTH_DBDIN,
           LKP_TYP_DBDIN,
           QTY_PLAN_DBDIN,
           COD_RUN_DBDIN,
           COD_ORDER_GROUP_DBDIN,
           QTY_max_DBDIN,
           QTY_min_DBDIN)
        values
          (lmp.lmp_cap_dbd_inputs_seq.nextval,
           i.bas_station_id,
           lv_month,
           'TOTAL_STATION_OG',
           greatest(lv_targ - (nvl(lv_act, 0)), 0),
           p_cod_run,
           og.cod_og,
           greatest(lv_max - (nvl(lv_act, 0)), 0),
           greatest(lv_min - (nvl(lv_act, 0)), 0));
      
      end loop;
    end loop;
  end;

  /* procedure cal_target_month_prc(p_cod_run in varchar2) is
     lv_month       varchar2(6);
     lv_start_dat   date;
     lv_end_dat     date;
     lv_plan        number;
     lv_act         number;
     lv_plan_sch    number;
     lv_num_seq     number;
     lv_dat_end_act date;
     lv_max         number;
     lv_min         number;
     lv_targ        number;
   begin
     select h.dat_strt_hrzn_rnhis
       into lv_start_dat
       from lmp.lmp_bas_run_histories h
      where h.cod_run_rnhis = p_cod_run;
     lv_dat_end_act := lv_start_dat;
     lv_month       := to_char(lv_start_dat, 'YYYYMM');
     dbms_output.put_line(lv_month);
     select min(c.Dat_Calde)
       into lv_start_dat
       from aac_lmp_calendar_viw c
      where c.v_Dat_Calde_In_6 = lv_month;
     lv_end_dat := trunc(sysdate);
     lv_num_seq := app_lmp_params_pkg.update_str_date_smp_rep_fun(p_date => lv_start_dat);
     lv_num_seq := app_lmp_params_pkg.update_end_date_smp_rep_fun(p_date => lv_end_dat);
   
     App_Pms_For_Mas_Pkg.set_param_for_mas_viw_prc(lv_start_dat,
                                                   lv_end_dat,
                                                   NULL,
                                                   1);
     apps.APP_PMS_FOR_SMP_PKG.Set_Date_Prc(lv_start_dat, lv_end_dat);
    for i in (select cdi.statn_bas_station_id,
                      --cdi.qty_plan_dbdin,
                      cdi.qty_min_dbdin,
                      cdi.qty_max_dbdin,
                      pa.area_id,
                      pa.arstu_ide_pk_arstu
                 from LMP.LMP_CAP_DBD_INPUTS cdi,
                      lmp_bas_stations       st,
                      pms_areas              pa
                where cdi.lkp_typ_dbdin = 'TOTAL_STATION'
                  and cdi.val_month_dbdin = lv_month
                  and pa.area_id = st.area_area_id
                  and st.bas_station_id = cdi.statn_bas_station_id
                  and cdi.cod_run_dbdin = '0'
                  and (nvl(cdi.qty_plan_dbdin, 0) + nvl(cdi.qty_min_dbdin, 0) +
                      nvl(cdi.qty_max_dbdin, 0)) > 0
               --and cdi.qty_plan_dbdin is not null
               ) loop
           begin
             select ts.qty_plan_lstst
               into lv_plan
               from lmp.lmp_sop_target_stations ts
              where ts.cod_run_cap_lstst = '0'
                and ts.lkp_type_lstst = 'CAP_TARGET_STATION'
                and ts.statn_bas_station_id = i.statn_bas_station_id
                and ts.val_month_lstst = lv_month;
           exception
             when no_data_found then
               lv_plan := 0;
           end;
       --smc
       if i.statn_bas_station_id = 41 then
         --lv_plan := nvl(i.qty_plan_dbdin, 0);
         lv_min  := nvl(i.qty_min_dbdin, 0);
         lv_max  := nvl(i.qty_max_dbdin, 0);
         select nvl(round(sum(wp.WEI_ACTL_PRODT) / 1000), 0)
           into lv_act
           from PMS_FOR_LMP_WEI_PROD_VIW wp
          where wp.NAM_BRIEF like 'CCM%'
            and wp.DATE_GEN < lv_dat_end_act;
       
         select nvl(round(sum(t1.WEI_ASSIGNED_KG) / 1000), 0)
           into lv_plan_sch
           from apps.mas_lmp_assigned_slab_typ_viw t1
          where t1.NUM_AREA_ID_LOC_AASTH in (161, 160, 162, 163, 7375133);
       
         insert into LMP.LMP_CAP_DBD_INPUTS
           (CAP_DBD_INPUT_ID,
            STATN_BAS_STATION_ID,
            VAL_MONTH_DBDIN,
            LKP_TYP_DBDIN,
            QTY_PLAN_DBDIN,
            QTY_MIN_DBDIN,
            QTY_MAX_DBDIN,
            COD_RUN_DBDIN)
         values
           (lmp.lmp_cap_dbd_inputs_seq.nextval,
            i.statn_bas_station_id,
            lv_month,
            'TOTAL_STATION',
            greatest(lv_plan - (nvl(lv_act, 0) + nvl(lv_plan_sch, 0)), 0),
            greatest(lv_min - (nvl(lv_act, 0) + nvl(lv_plan_sch, 0)), 0),
            greatest(lv_max - (nvl(lv_act, 0) + nvl(lv_plan_sch, 0)), 0),
            p_cod_run);
       end if;
     
       --51
       if i.statn_bas_station_id = 45 then
        -- lv_plan := nvl(i.qty_plan_dbdin, 0);
         lv_min  := nvl(i.qty_min_dbdin, 0);
         lv_max  := nvl(i.qty_max_dbdin, 0);
         select nvl(sum(t.wei_actl_prdst) / 1000, 0)
           into lv_act
           from apps.hsm_lmp_coil_51_produce_viw t
          where trunc(t.DAT_REF_PRO_PRDST) >= lv_start_dat
            and trunc(t.DAT_REF_PRO_PRDST) < lv_dat_end_act;
         insert into LMP.LMP_CAP_DBD_INPUTS
           (CAP_DBD_INPUT_ID,
            STATN_BAS_STATION_ID,
            VAL_MONTH_DBDIN,
            LKP_TYP_DBDIN,
            QTY_PLAN_DBDIN,
            QTY_MIN_DBDIN,
            QTY_MAX_DBDIN,
            COD_RUN_DBDIN)
         values
           (lmp.lmp_cap_dbd_inputs_seq.nextval,
            i.statn_bas_station_id,
            lv_month,
            'TOTAL_STATION',
            greatest(lv_plan - lv_act, 0),
            greatest(lv_min - lv_act, 0),
            greatest(lv_max - lv_act, 0),
            p_cod_run);
       end if;
     
       if i.statn_bas_station_id = 3 then
         --lv_plan := nvl(i.qty_plan_dbdin, 0);
         lv_min  := nvl(i.qty_min_dbdin, 0);
         lv_max  := nvl(i.qty_max_dbdin, 0);
       
         select nvl(sum(t.wei_net_prdst) / 1000, 0)
           into lv_act
           from apps.ccm_lmp_accept_coil_viw t
          where trunc(t.DAT_STK_PRDST) >= lv_start_dat
            and trunc(t.DAT_STK_PRDST) < lv_dat_end_act;
       
         insert into LMP.LMP_CAP_DBD_INPUTS
           (CAP_DBD_INPUT_ID,
            STATN_BAS_STATION_ID,
            VAL_MONTH_DBDIN,
            LKP_TYP_DBDIN,
            QTY_PLAN_DBDIN,
            QTY_MIN_DBDIN,
            QTY_MAX_DBDIN,
            COD_RUN_DBDIN)
         values
           (lmp.lmp_cap_dbd_inputs_seq.nextval,
            i.statn_bas_station_id,
            lv_month,
            'TOTAL_STATION',
            greatest(lv_plan - lv_act, 0),
            greatest(lv_min - lv_act, 0),
            greatest(lv_max - lv_act, 0),
            p_cod_run);
       else
         if i.arstu_ide_pk_arstu like 'M.S.C CO/M.S.C/CCM%' then
           --lv_plan := nvl(i.qty_plan_dbdin, 0);
           lv_min  := nvl(i.qty_min_dbdin, 0);
           lv_max  := nvl(i.qty_max_dbdin, 0);
         
           select nvl(sum(t.WEI) / 1000, 0) as sum_ton
             into lv_act
             from CCM_FOR_MAS_PROD_VIW t
            where t.AREA_ID = i.area_id
              and t.DAT < lv_dat_end_act;
         
           insert into LMP.LMP_CAP_DBD_INPUTS
             (CAP_DBD_INPUT_ID,
              STATN_BAS_STATION_ID,
              VAL_MONTH_DBDIN,
              LKP_TYP_DBDIN,
              QTY_PLAN_DBDIN,
              QTY_MIN_DBDIN,
              QTY_MAX_DBDIN,
              COD_RUN_DBDIN)
           values
             (lmp.lmp_cap_dbd_inputs_seq.nextval,
              i.statn_bas_station_id,
              lv_month,
              'TOTAL_STATION',
              greatest(lv_plan - lv_act, 0),
              greatest(lv_min - lv_act, 0),
              greatest(lv_max - lv_act, 0),
              p_cod_run);
         end if;
       end if;
     end loop;
     
     --محاسبه گروه سفارش براي خطوط سرد
     for i in (select st.bas_station_id, pa.area_id
                 from lmp.lmp_bas_stations st, pms_areas pa
                where pa.area_id = st.area_area_id
                  and pa.arstu_ide_pk_arstu like 'M.S.C CO/M.S.C/CCM%') loop
       for og in (select fp.val_att4_lmpfp as cod_og
                    from lmp.lmp_bas_fix_params fp
                   where fp.lkp_typ_lmpfp = 'DAY_BY_DAY'
                     and fp.val_att1_lmpfp = i.bas_station_id) loop
         select sum(dd.qty_prod_plan_dayby)
           into lv_plan
           from lmp.lmp_bas_day_by_days dd
          where dd.statn_bas_station_id = i.bas_station_id
            and dd.cod_ord_grp_dayby = og.cod_og
            and to_char(dd.dat_day_dayby, 'YYYYMM') = lv_month;
       
         begin
           select t2.qty_max_dbdin, t2.qty_min_dbdin--, t2.qty_plan_dbdin
             into lv_max, lv_min--, lv_targ
             from lmp.lmp_cap_dbd_inputs t2
            where t2.lkp_typ_dbdin = 'TOTAL_STATION_OG'
              and t2.statn_bas_station_id = i.bas_station_id
              and t2.cod_run_dbdin = '0'
              and t2.val_month_dbdin = lv_month
              and t2.cod_order_group_dbdin = og.cod_og;
         exception
           when others then
             lv_max  := null;
             lv_min  := null;
             lv_targ := null;
         end;
         begin
             select ts.qty_plan_lstst
               into lv_targ
               from lmp.lmp_sop_target_stations ts
              where ts.cod_run_cap_lstst = '0'
                and ts.lkp_type_lstst = 'CAP_TARGET_OG'
                and ts.statn_bas_station_id = i.bas_station_id
                and ts.val_month_lstst = lv_month
                and ts.cod_order_group_lstst = og.COD_OG;
           exception
             when no_data_found then
               lv_targ := null;
           end;
           
         lv_targ := nvl(lv_targ, lv_plan);
         select (sum(t.WEI) / 1000)
           into lv_act
           from CCM_FOR_MAS_PROD_VIW t
          where t.DAT < lv_dat_end_act
            and t.AREA_ID = i.area_id
            and lmp_ret_ord_group_for_ord_fun(p_cod_order => t.ORDIT_ORDHE_COD_ORD_ORDHE ||
                                                             lpad(t.ORDIT_NUM_ITEM_ORDIT,
                                                                  3,
                                                                  '0')) =
                og.cod_og;
       
         insert into LMP.LMP_CAP_DBD_INPUTS
           (CAP_DBD_INPUT_ID,
            STATN_BAS_STATION_ID,
            VAL_MONTH_DBDIN,
            LKP_TYP_DBDIN,
            QTY_PLAN_DBDIN,
            COD_RUN_DBDIN,
            COD_ORDER_GROUP_DBDIN,
            QTY_max_DBDIN,
            QTY_min_DBDIN)
         values
           (lmp.lmp_cap_dbd_inputs_seq.nextval,
            i.bas_station_id,
            lv_month,
            'TOTAL_STATION_OG',
            greatest(lv_targ - nvl(lv_act, 0), 0),
            p_cod_run,
            og.cod_og,
            greatest(lv_max - nvl(lv_act, 0), 0),
            greatest(lv_min - nvl(lv_act, 0), 0));
       
       end loop;
     end loop;
   
     --51 for og
     for j in (select cdi.statn_bas_station_id,
                      --cdi.qty_plan_dbdin,
                      cdi.qty_max_dbdin,
                      cdi.qty_min_dbdin,
                      cdi.cod_order_group_dbdin,
                      pa.area_id,
                      pa.arstu_ide_pk_arstu
                 from LMP.LMP_CAP_DBD_INPUTS cdi,
                      lmp_bas_stations       st,
                      pms_areas              pa
                where cdi.lkp_typ_dbdin = 'TOTAL_STATION_OG'
                  and cdi.val_month_dbdin = lv_month
                  and pa.area_id = st.area_area_id
                  and st.bas_station_id = cdi.statn_bas_station_id
                  and cdi.cod_run_dbdin = '0'
                  and st.bas_station_id = 45) loop
                  
           begin
             select ts.qty_plan_lstst
               into lv_targ
               from lmp.lmp_sop_target_stations ts
              where ts.cod_run_cap_lstst = '0'
                and ts.lkp_type_lstst = 'CAP_TARGET_OG'
                and ts.statn_bas_station_id = j.statn_bas_station_id
                and ts.val_month_lstst = lv_month
                and ts.cod_order_group_lstst = j.cod_order_group_dbdin;
           exception
             when no_data_found then
               lv_targ := 0;
           end;
           
       select nvl(sum(tt.wei_actl_prdst) / 1000, 0)
         into lv_act
         from apps.hsm_lmp_coil_51_produce_viw tt
        where trunc(tt.DAT_REF_PRO_PRDST) >= lv_start_dat
          and trunc(tt.DAT_REF_PRO_PRDST) < lv_dat_end_act
          and tt.COD_ORD_GRP_PRDST = j.cod_order_group_dbdin;
          
       insert into LMP.LMP_CAP_DBD_INPUTS
         (CAP_DBD_INPUT_ID,
          STATN_BAS_STATION_ID,
          VAL_MONTH_DBDIN,
          LKP_TYP_DBDIN,
          QTY_PLAN_DBDIN,
          COD_RUN_DBDIN,
          COD_ORDER_GROUP_DBDIN,
          qty_max_dbdin,
          qty_min_dbdin)
       values
         (lmp.lmp_cap_dbd_inputs_seq.nextval,
          j.statn_bas_station_id,
          lv_month,
          'TOTAL_STATION_OG',
          greatest(lv_targ - lv_act, 0),
          p_cod_run,
          j.cod_order_group_dbdin,
          greatest(j.qty_max_dbdin - lv_act, 0),
          greatest(j.qty_min_dbdin - lv_act, 0));
     end loop;
   
     --محاسبه گروه سفارش براي ريخته گري
     for i in (select st.bas_station_id, pa.area_id
                 from lmp.lmp_bas_stations st, pms_areas pa
                where pa.area_id = st.area_area_id
                  and st.bas_station_id = 41) loop
       for og in (select fp.val_att4_lmpfp as cod_og
                    from lmp.lmp_bas_fix_params fp
                   where fp.lkp_typ_lmpfp = 'DAY_BY_DAY'
                     and fp.val_att1_lmpfp = i.bas_station_id) loop
       
         begin
           select t2.qty_max_dbdin, t2.qty_min_dbdin--, t2.qty_plan_dbdin
             into lv_max, lv_min--, lv_targ
             from lmp.lmp_cap_dbd_inputs t2
            where t2.lkp_typ_dbdin = 'TOTAL_STATION_OG'
              and t2.statn_bas_station_id = i.bas_station_id
              and t2.cod_run_dbdin = '0'
              and t2.val_month_dbdin = lv_month
              and t2.cod_order_group_dbdin = og.cod_og;
         exception
           when others then
             lv_max  := null;
             lv_min  := null;
             lv_targ := null;
         end;
         
        begin
             select ts.qty_plan_lstst
               into lv_targ
               from lmp.lmp_sop_target_stations ts
              where ts.cod_run_cap_lstst = '0'
                and ts.lkp_type_lstst = 'CAP_TARGET_OG'
                and ts.statn_bas_station_id = i.bas_station_id
                and ts.val_month_lstst = lv_month
                and ts.cod_order_group_lstst = og.COD_OG;
           exception
             when no_data_found then
               lv_targ := null;
           end;
           
         if nvl(lv_max, 0) + nvl(lv_targ, 0) + nvl(lv_min, 0) = 0 then
           continue;
         end if;
       
         select round(sum(tt.WEI_ACTL_PRDST) / 1000)
           into lv_act
           from apps.pms_for_smp_slab_prod_viw tt
          where lmp_ret_ord_group_for_ord_fun(tt.numorder) = og.cod_og;
       
         insert into LMP.LMP_CAP_DBD_INPUTS
           (CAP_DBD_INPUT_ID,
            STATN_BAS_STATION_ID,
            VAL_MONTH_DBDIN,
            LKP_TYP_DBDIN,
            QTY_PLAN_DBDIN,
            COD_RUN_DBDIN,
            COD_ORDER_GROUP_DBDIN,
            QTY_max_DBDIN,
            QTY_min_DBDIN)
         values
           (lmp.lmp_cap_dbd_inputs_seq.nextval,
            i.bas_station_id,
            lv_month,
            'TOTAL_STATION_OG',
            greatest(lv_targ - (nvl(lv_act, 0)), 0),
            p_cod_run,
            og.cod_og,
            greatest(lv_max - (nvl(lv_act, 0)), 0),
            greatest(lv_min - (nvl(lv_act, 0)), 0));
       
       end loop;
     end loop;
   end;
  */ -----------------------
  ---------------------------------------------
  procedure cal_fill_prc(p_cod_run in varchar2) is
  begin
    app_lmp_cap_reports_pkg.fill_plan_act_cod_run_prc(p_cod_run => p_cod_run);
    app_lmp_cap_reports_pkg.get_round_plan_prc(p_cod_run => p_cod_run);
  end;
  --------------------------------------------
  procedure upd_mas_prc is
  begin
    update mas.mas_msch_run_histories tt
       set tt.lkp_sta_model_mrhis = 'ERROR'
     where tt.msch_run_history_id = 33759;
    commit;
  end;
  -------------------------------------------
  procedure check_end_model_prc is
    lv_num               number;
    lv_connection_server varchar2(100);
  begin
    -- null;
    for i in (select h.cod_run_rnhis
                from lmp.lmp_bas_run_histories h
               where trunc(h.dat_run_rnhis) = trunc(sysdate)
                 and h.sta_run_rnhis = 2
                 and h.num_module_rnhis = 3) loop
      select name into lv_connection_server from v$database;
      app_lmp_global_pkg.insert_log_prc(p_fun_nam   => 'check_end_model_prc',
                                        p_inputs    => i.cod_run_rnhis || '_' ||
                                                       lv_connection_server,
                                        p_outputs   => to_char(sysdate,
                                                               'YYYYMMDD'),
                                        p_flg_ok    => 1,
                                        p_des_error => null);
      commit;
      lv_num := APP_LMP_CAP_TOT_MODEL_PKG.run_cap_model_fun(p_cod_run           => i.cod_run_rnhis,
                                                            p_connection_server => lv_connection_server,
                                                            p_identifierName    => '2');
      commit;
    end loop;
  end;
  ---------------------------------
  procedure run_model_manual_prc(p_flg_run_service in number) is
    lv_cod_run           varchar2(15);
    lv_connection_server varchar2(30);
    lv_string            varchar2(1000);
    lv_num               number := 1;
    lv_msg               varchar2(1000);
  begin
    --create cod_run
    lv_cod_run := APP_LMP_CAP_TOT_MODEL_PKG.CREATE_COD_RUN_FUN(p_dat_start => trunc(sysdate),
                                                               P_dat_end   => trunc(sysdate + 29 + 30),
                                                               /*P_dat_end   => trunc(sysdate + 20),*/
                                                               p_des       => 'Scheduled ' ||
                                                                              to_char(sysdate,
                                                                                      'YYYY-MM-DD hh:mi:ss'));
  
    APP_LMP_CAP_TOT_MODEL_PKG.create_model_data_prc(p_cod_run => lv_cod_run);
  
    dbms_output.put_line(lv_cod_run);
    -----
    delete from LMP.LMP_CAP_DBD_INPUTS t
     where t.lkp_typ_dbdin = 'FIX_TON_DAY'
       and cod_run_dbdin = lv_cod_run
       and t.statn_bas_station_id is null;
    --lv_cod_run:='CAP1397061401';
    commit;
  
    --call webservice
    if nvl(p_flg_run_service, 0) = 1 then
      begin
        lv_msg := Fnd.Fnd_Sms_And_Email_Pkg.Send_Non_Adv_Sms_Fun(sys.odciVarchar2List('09131657097'),
                                                                 p_Messagebodies => 'DONE' ||
                                                                                    ' : ' ||
                                                                                    to_char(sysdate,
                                                                                            'MM/DD HH24:MI'));
      exception
        when others then
          null;
      end;
      --Dbms_lock.sleep(60);
      select name into lv_connection_server from v$database;
      lv_num := APP_LMP_CAP_TOT_MODEL_PKG.run_cap_model_fun(p_cod_run           => lv_cod_run,
                                                            p_connection_server => lv_connection_server,
                                                            p_identifierName    => '1');
    
    end if;
    commit;
  
  end;

  --------------------------------
  procedure update_target_month_prc(p_qty_plan   in number,
                                    p_cod_run    in varchar2,
                                    p_station_id in number,
                                    p_month      in varchar2) is
    lv_lkp_type varchar2(30) := 'TOTAL_STATION';
  begin
    update LMP.LMP_CAP_DBD_INPUTS cd
       set cd.qty_plan_dbdin = greatest(cd.qty_plan_dbdin - p_qty_plan, 0),
           cd.qty_max_dbdin  = greatest((cd.qty_max_dbdin - p_qty_plan), 0),
           cd.qty_min_dbdin  = greatest((cd.qty_min_dbdin - p_qty_plan), 0)
     where cd.statn_bas_station_id = p_station_id
       and cd.lkp_typ_dbdin = lv_lkp_type
       and cd.cod_run_dbdin = p_cod_run
       and cd.val_month_dbdin = p_month;
  
  end;
  --------------------------------
  procedure update_target_OG_month_prc(p_qty_plan   in number,
                                       p_cod_run    in varchar2,
                                       p_station_id in number,
                                       p_month      in varchar2,
                                       p_orderGroup in varchar2) is
    lv_lkp_type varchar2(30) := 'TOTAL_STATION_OG';
  begin
    update LMP.LMP_CAP_DBD_INPUTS cd
       set cd.qty_plan_dbdin = greatest(cd.qty_plan_dbdin - p_qty_plan, 0),
           cd.qty_max_dbdin  = greatest((cd.qty_max_dbdin - p_qty_plan), 0),
           cd.qty_min_dbdin  = greatest((cd.qty_min_dbdin - p_qty_plan), 0)
     where cd.statn_bas_station_id = p_station_id
       and cd.lkp_typ_dbdin = lv_lkp_type
       and cd.cod_run_dbdin = p_cod_run
       and cd.val_month_dbdin = p_month
       and cd.cod_order_group_dbdin = p_orderGroup;
  
  end;
  --------------------------------
  -- Added by m.enteshri 970322
  procedure fill_crm_balance_report_prc(p_cod_run in varchar2) is
    lv_lkp         varchar2(50) := 'CAP_CRM_BALANCE'; -- ?? Ask from Safa 'CAP_CRM_BALANCE'
    lv_start_dat   date;
    lv_end_dat     date;
    lv_first_inv   number;
    lv_last_inv    number;
    lv_num_seq     number;
    lv_production  number;
    lv_optimal_inv number;
  begin
    delete from lmp.lmp_cap_dbd_reports td
     where td.lkp_typ_dbdrp = lv_lkp
       and td.cod_run_dbdrp = p_cod_run;
  
    select rh.dat_strt_hrzn_rnhis, rh.dat_end_hrzn_rnhis
      into lv_start_dat, lv_end_dat
      from lmp.lmp_bas_run_histories rh
     where rh.cod_run_rnhis = p_cod_run;
  
    for s in (select unique(st.lkp_parent_statn) --st.bas_station_id, pa.area_id
                from lmp.lmp_bas_stations st --, pms_areas pa
               where st.lkp_group_statn = 'LMP'
                 and st.flg_cap_active_statn = 1
                 and st.lkp_parent_statn is not null
              --and st.area_area_id = pa.area_id
              ) loop
    
      ---- ****** fOR TOT STAION, ORDER GROUP IS NULL ***** -----
    
      select round(sum(im.mu_wei) / 1000)
        into lv_first_inv
        from mas_lmp_initial_mu_viw im,
             lmp.lmp_bas_orders     o,
             lmp_bas_stations       st
       where im.station_id = st.bas_station_id
         and st.lkp_parent_statn = s.lkp_parent_statn
         and o.cod_run_lmpor = p_cod_run
         and o.cod_order_lmpor = im.cod_ord_ordhe
         and o.num_order_lmpor = im.num_item_ordit;
    
      select round(sum(st.qty_inv_cap_statn))
        into lv_optimal_inv
        from lmp_bas_stations st
       where st.lkp_parent_statn = s.lkp_parent_statn;
      --???? ask from safa for all days???
    
      for i in (select c.Dat_Calde
                  from aac_lmp_calendar_viw c
                 where c.Dat_Calde between lv_start_dat and lv_end_dat
                 order by c.Dat_Calde) loop
        ----- FIRST INVENTORY -----
        lv_num_seq := 1000; --?????
        insert into lmp.lmp_cap_dbd_reports
          (cap_dbd_report_id,
           typ_item_dbdrp,
           nam_farsi_dbdrp,
           dat_day_dbdrp,
           nam_prod_dbdrp,
           qty_item_dbdrp,
           lkp_typ_dbdrp,
           NAM_STAION_PARENT_DBDRP,
           NUM_SEQ_DBDRP,
           COD_RUN_DBDRP)
        values
          (lmp.lmp_cap_dbd_reports_seq.nextval,
           'FIRST_INV',
           '????I? CEEIC? I???',
           i.dat_calde,
           null,
           lv_first_inv,
           lv_lkp,
           s.lkp_parent_statn,
           lv_num_seq,
           p_cod_run);
      
        ----- LAST INVENTORY -----
        select round(sum(ip.qty_inventory_invpl))
          into lv_last_inv
          from lmp.lmp_bas_inv_plans ip, lmp_bas_stations st
         where ip.cod_run_invpl = p_cod_run
           and ip.cod_statn_invpl = st.bas_station_id
           and st.lkp_parent_statn = s.lkp_parent_statn
           and ip.dat_day_invpl = i.dat_calde;
        lv_num_seq := 9000; --????
        insert into lmp.lmp_cap_dbd_reports
          (cap_dbd_report_id,
           typ_item_dbdrp,
           nam_farsi_dbdrp,
           dat_day_dbdrp,
           nam_prod_dbdrp,
           qty_item_dbdrp,
           lkp_typ_dbdrp,
           NAM_STAION_PARENT_DBDRP,
           NUM_SEQ_DBDRP,
           COD_RUN_DBDRP)
        values
          (lmp.lmp_cap_dbd_reports_seq.nextval,
           'LAST_INV',
           '????I? C?E?C? I???',
           i.dat_calde,
           null,
           lv_last_inv,
           lv_lkp,
           s.lkp_parent_statn,
           lv_num_seq,
           p_cod_run);
        lv_first_inv := lv_last_inv;
      
        ---- RECIEVE ----
        for j in (select m.bas_station_id,
                         m.seq_sequence_statn,
                         m.nam_ful_far_area,
                         m.Dat_Calde,
                         d.sum_ton
                    from (select ms.bas_station_id,
                                 ms.seq_sequence_statn,
                                 ms.nam_ful_far_area,
                                 cal.Dat_Calde
                            from (select distinct st.bas_station_id,
                                                  st.seq_sequence_statn,
                                                  pa.nam_ful_far_area
                                    from lmp.lmp_bas_transport_plans tp,
                                         lmp.lmp_bas_stations        st,
                                         pms_areas                   pa
                                   where tp.cod_run_trapl = p_cod_run
                                     and tp.cod_statn_to_trapl in -- added new
                                         (select sts.bas_station_id
                                            from lmp_bas_stations sts
                                           where sts.lkp_parent_statn =
                                                 s.lkp_parent_statn)
                                     and st.bas_station_id =
                                         tp.cod_statn_from_trapl
                                     and st.area_area_id = pa.area_id) ms,
                                 (select distinct c.Dat_Calde
                                    from aac_lmp_calendar_viw c
                                   where c.Dat_Calde = i.dat_calde) cal) m,
                         (select tp.cod_statn_from_trapl,
                                 tp.dat_day_trapl,
                                 round(sum(tp.qty_tranport_trapl)) sum_ton
                            from lmp.lmp_bas_transport_plans tp,
                                 lmp.lmp_bas_stations        st,
                                 pms_areas                   pa
                           where tp.cod_run_trapl = p_cod_run
                             and tp.cod_statn_to_trapl in -- added new
                                 (select sts.bas_station_id
                                    from lmp_bas_stations sts
                                   where sts.lkp_parent_statn =
                                         s.lkp_parent_statn)
                             and st.bas_station_id = tp.cod_statn_from_trapl
                             and st.area_area_id = pa.area_id
                           group by tp.cod_statn_from_trapl, tp.dat_day_trapl) d
                   where m.bas_station_id = d.cod_statn_from_trapl(+)
                     and m.Dat_Calde = d.dat_day_trapl(+)
                   order by m.seq_sequence_statn) loop
        
          lv_num_seq := 2000 + j.seq_sequence_statn; --???
          insert into lmp.lmp_cap_dbd_reports
            (cap_dbd_report_id,
             typ_item_dbdrp,
             nam_farsi_dbdrp,
             dat_day_dbdrp,
             nam_prod_dbdrp,
             qty_item_dbdrp,
             lkp_typ_dbdrp,
             NAM_STAION_PARENT_DBDRP,
             NUM_SEQ_DBDRP,
             COD_RUN_DBDRP)
          values
            (lmp.lmp_cap_dbd_reports_seq.nextval,
             'RECIEVE',
             'I??C?E',
             i.dat_calde,
             j.nam_ful_far_area,
             j.sum_ton,
             lv_lkp,
             s.lkp_parent_statn,
             lv_num_seq,
             p_cod_run);
        end loop;
      
        ----- PRODUCTION ----
        select round(t.sum_ton)
          into lv_production
          from (select distinct c.Dat_Calde
                  from aac_lmp_calendar_viw c
                 where c.Dat_Calde = i.dat_calde) cal,
               (select bpf.dat_day_prppf, sum(bpf.qty_prod_prppf) as sum_ton
                  from lmp.lmp_bas_production_plan_pfs bpf,
                       lmp_bas_stations                st
                 where bpf.cod_run_prppf = p_cod_run
                   and bpf.cod_statn_prppf = st.bas_station_id
                   and st.lkp_parent_statn = s.lkp_parent_statn
                 group by bpf.dat_day_prppf) t
         where cal.Dat_Calde = t.dat_day_prppf(+)
           and cal.Dat_Calde = i.dat_calde;
        lv_num_seq := 3000;
        insert into lmp.lmp_cap_dbd_reports
          (cap_dbd_report_id,
           typ_item_dbdrp,
           nam_farsi_dbdrp,
           dat_day_dbdrp,
           nam_prod_dbdrp,
           qty_item_dbdrp,
           lkp_typ_dbdrp,
           NAM_STAION_PARENT_DBDRP,
           NUM_SEQ_DBDRP,
           COD_RUN_DBDRP)
        values
          (lmp.lmp_cap_dbd_reports_seq.nextval,
           'PRODUCTION',
           'E???I',
           i.dat_calde,
           null,
           lv_production,
           lv_lkp,
           s.lkp_parent_statn,
           lv_num_seq,
           p_cod_run);
      
        ----- OPTIMAL INVENTORY ----
      
        lv_num_seq := 4000; --????? ask from safa
        insert into lmp.lmp_cap_dbd_reports
          (cap_dbd_report_id,
           typ_item_dbdrp,
           nam_farsi_dbdrp,
           dat_day_dbdrp,
           nam_prod_dbdrp,
           qty_item_dbdrp,
           lkp_typ_dbdrp,
           NAM_STAION_PARENT_DBDRP,
           NUM_SEQ_DBDRP,
           COD_RUN_DBDRP)
        values
          (lmp.lmp_cap_dbd_reports_seq.nextval,
           'OPTIMAL_INV',
           '????I? E????',
           i.dat_calde,
           null,
           lv_optimal_inv,
           lv_lkp,
           s.lkp_parent_statn,
           lv_num_seq,
           p_cod_run);
      
      end loop; -- loop of days
    
      ---- ****** fOR ORDER GROUP *****-----
      /* for og in (select fp.val_att4_lmpfp as cod_og
       from lmp.lmp_bas_fix_params fp
      where fp.lkp_typ_lmpfp = 'DAY_BY_DAY'
        and fp.val_att1_lmpfp = s.bas_station_id) loop*/
      for og in (select fp.val_att4_lmpfp as cod_og
                   from lmp.lmp_bas_fix_params fp
                  where fp.lkp_typ_lmpfp = 'DAY_BY_DAY'
                    and fp.val_att1_lmpfp = s.Lkp_Parent_Statn) loop
      
        --??? Ask from safa val_att1_lmpfp should be added for new form???
      
        select round(sum(im.mu_wei) / 1000)
          into lv_first_inv
          from mas_lmp_initial_mu_viw im,
               lmp.lmp_bas_orders     o,
               lmp_bas_stations       st
         where im.station_id = st.bas_station_id
           and st.lkp_parent_statn = s.lkp_parent_statn
           and o.cod_run_lmpor = p_cod_run
           and o.cod_order_lmpor = im.cod_ord_ordhe
           and o.num_order_lmpor = im.num_item_ordit
           and LMP_RET_ORD_GROUP_FOR_ORD_FUN(p_cod_order => o.cod_order_lmpor ||
                                                            lpad(o.num_order_lmpor,
                                                                 3,
                                                                 '0')) =
               og.cod_og;
      
        for i in (select c.Dat_Calde
                    from aac_lmp_calendar_viw c
                   where c.Dat_Calde between lv_start_dat and lv_end_dat
                   order by c.Dat_Calde) loop
          ----- FIRST INVENTORY -----
          lv_num_seq := 1000;
          insert into lmp.lmp_cap_dbd_reports
            (cap_dbd_report_id,
             typ_item_dbdrp,
             nam_farsi_dbdrp,
             dat_day_dbdrp,
             nam_prod_dbdrp,
             qty_item_dbdrp,
             lkp_typ_dbdrp,
             nam_staion_parent_dbdrp,
             NUM_SEQ_DBDRP,
             COD_RUN_DBDRP,
             COD_ORDER_GROUP_DBDRP)
          values
            (lmp.lmp_cap_dbd_reports_seq.nextval,
             'FIRST_INV',
             '????I? CEEIC? I???',
             i.dat_calde,
             null,
             lv_first_inv,
             lv_lkp,
             s.lkp_parent_statn,
             lv_num_seq,
             p_cod_run,
             og.cod_og);
        
          ----- LAST INVENTORY -----
          select round(sum(ip.qty_inventory_invpl))
            into lv_last_inv
            from lmp.lmp_bas_inv_plans ip, lmp_bas_stations st
           where ip.cod_run_invpl = p_cod_run
             and ip.cod_statn_invpl = st.bas_station_id
             and st.lkp_parent_statn = s.lkp_parent_statn
             and ip.dat_day_invpl = i.dat_calde
             and ip.cod_order_group_invpl = og.cod_og;
          lv_num_seq := 9000;
          insert into lmp.lmp_cap_dbd_reports
            (cap_dbd_report_id,
             typ_item_dbdrp,
             nam_farsi_dbdrp,
             dat_day_dbdrp,
             nam_prod_dbdrp,
             qty_item_dbdrp,
             lkp_typ_dbdrp,
             nam_staion_parent_dbdrp,
             NUM_SEQ_DBDRP,
             COD_RUN_DBDRP,
             COD_ORDER_GROUP_DBDRP)
          values
            (lmp.lmp_cap_dbd_reports_seq.nextval,
             'LAST_INV',
             '????I? C?E?C? I???',
             i.dat_calde,
             null,
             lv_last_inv,
             lv_lkp,
             s.lkp_parent_statn,
             lv_num_seq,
             p_cod_run,
             og.cod_og);
          lv_first_inv := lv_last_inv;
        
          ---- RECIEVE ----
          for j in (select m.bas_station_id,
                           m.seq_sequence_statn,
                           m.nam_ful_far_area,
                           m.Dat_Calde,
                           d.sum_ton
                      from (select ms.bas_station_id,
                                   ms.seq_sequence_statn,
                                   ms.nam_ful_far_area,
                                   cal.Dat_Calde
                              from (select distinct st.bas_station_id,
                                                    st.seq_sequence_statn,
                                                    pa.nam_ful_far_area
                                      from lmp.lmp_bas_transport_plans tp,
                                           lmp.lmp_bas_stations        st,
                                           pms_areas                   pa
                                     where tp.cod_run_trapl = p_cod_run
                                       and tp.cod_statn_to_trapl in -- added new
                                           (select sts.bas_station_id
                                              from lmp_bas_stations sts
                                             where sts.lkp_parent_statn =
                                                   s.lkp_parent_statn)
                                       and st.bas_station_id =
                                           tp.cod_statn_from_trapl
                                       and st.area_area_id = pa.area_id) ms,
                                   (select distinct c.Dat_Calde
                                      from aac_lmp_calendar_viw c
                                     where c.Dat_Calde = i.dat_calde) cal) m,
                           (select tp.cod_statn_from_trapl,
                                   tp.dat_day_trapl,
                                   round(sum(tp.qty_tranport_trapl)) sum_ton
                              from lmp.lmp_bas_transport_plans tp,
                                   lmp.lmp_bas_stations        st,
                                   pms_areas                   pa
                             where tp.cod_run_trapl = p_cod_run
                               and tp.cod_statn_to_trapl in -- added new
                                   (select sts.bas_station_id
                                      from lmp_bas_stations sts
                                     where sts.lkp_parent_statn =
                                           s.lkp_parent_statn)
                               and st.bas_station_id =
                                   tp.cod_statn_from_trapl
                               and st.area_area_id = pa.area_id
                               and tp.cod_order_group_trapl = og.cod_og
                             group by tp.cod_statn_from_trapl,
                                      tp.dat_day_trapl) d
                     where m.bas_station_id = d.cod_statn_from_trapl(+)
                       and m.Dat_Calde = d.dat_day_trapl(+)
                     order by m.seq_sequence_statn) loop
            lv_num_seq := 2000 + j.seq_sequence_statn;
            insert into lmp.lmp_cap_dbd_reports
              (cap_dbd_report_id,
               typ_item_dbdrp,
               nam_farsi_dbdrp,
               dat_day_dbdrp,
               nam_prod_dbdrp,
               qty_item_dbdrp,
               lkp_typ_dbdrp,
               nam_staion_parent_dbdrp,
               NUM_SEQ_DBDRP,
               COD_RUN_DBDRP,
               COD_ORDER_GROUP_DBDRP)
            values
              (lmp.lmp_cap_dbd_reports_seq.nextval,
               'RECIEVE',
               'I??C?E',
               i.dat_calde,
               j.nam_ful_far_area,
               j.sum_ton,
               lv_lkp,
               s.lkp_parent_statn,
               lv_num_seq,
               p_cod_run,
               og.cod_og);
          end loop;
        
          ---- PRODUCTION ----
          select round(t.sum_ton)
            into lv_production
            from (select distinct c.Dat_Calde
                    from aac_lmp_calendar_viw c
                   where c.Dat_Calde = i.dat_calde) cal,
                 (select bpf.dat_day_prppf,
                         sum(bpf.qty_prod_prppf) as sum_ton
                    from lmp.lmp_bas_production_plan_pfs bpf,
                         lmp_bas_stations                st
                   where bpf.cod_run_prppf = p_cod_run
                     and bpf.cod_statn_prppf = st.bas_station_id
                     and st.lkp_parent_statn = s.lkp_parent_statn
                     and bpf.cod_order_group_prppf = og.cod_og
                   group by bpf.dat_day_prppf) t
           where cal.Dat_Calde = t.dat_day_prppf(+)
             and cal.Dat_Calde = i.dat_calde;
          lv_num_seq := 3000;
          insert into lmp.lmp_cap_dbd_reports
            (cap_dbd_report_id,
             typ_item_dbdrp,
             nam_farsi_dbdrp,
             dat_day_dbdrp,
             nam_prod_dbdrp,
             qty_item_dbdrp,
             lkp_typ_dbdrp,
             nam_staion_parent_dbdrp,
             NUM_SEQ_DBDRP,
             COD_RUN_DBDRP,
             COD_ORDER_GROUP_DBDRP)
          values
            (lmp.lmp_cap_dbd_reports_seq.nextval,
             'PRODUCTION',
             'E???I',
             i.dat_calde,
             null,
             lv_production,
             lv_lkp,
             s.lkp_parent_statn,
             lv_num_seq,
             p_cod_run,
             og.cod_og);
        
          ----- OPTIMAL INVENTORY ----
          select round(sum(ct.qty_avg_invog))
            into lv_optimal_inv
            from lmp.lmp_cap_inv_og_targets ct, lmp_bas_stations st
           where ct.statn_bas_station_id = st.bas_station_id
             and st.lkp_parent_statn = s.lkp_parent_statn
             and ct.cod_order_group_invog = og.cod_og;
        
          lv_num_seq := 4000; --????? ask from safa
          insert into lmp.lmp_cap_dbd_reports
            (cap_dbd_report_id,
             typ_item_dbdrp,
             nam_farsi_dbdrp,
             dat_day_dbdrp,
             nam_prod_dbdrp,
             qty_item_dbdrp,
             lkp_typ_dbdrp,
             NAM_STAION_PARENT_DBDRP,
             NUM_SEQ_DBDRP,
             COD_RUN_DBDRP)
          values
            (lmp.lmp_cap_dbd_reports_seq.nextval,
             'OPTIMAL_INV',
             '????I? E????',
             i.dat_calde,
             null,
             lv_optimal_inv,
             lv_lkp,
             s.lkp_parent_statn,
             lv_num_seq,
             p_cod_run);
        
        end loop; -- loop of days
      end loop; -- loop of og
    end loop; -- loop of stations
    --commit;
  end;

  -------------------------------------
  -- for Calling DBD Model In Master Forms by m.enteshari 971001
  function Run_Model_For_Mas_Fun(p_mas_run_id in number,
                                 p_num_module in number,
                                 p_des        IN VARCHAR2) return number is
    lv_cod_run           varchar2(15);
    lv_connection_server varchar2(30);
    lv_string            varchar2(1000);
    lv_num               number := 1;
    lv_msg               varchar2(1000);
  begin
  
    --create virtual orders
    /*app_lmp_sop_model_pkg.create_order_info_tot_prc;
    app_lmp_sop_model_pkg.create_virtual_order_prc;
    app_lmp_global_pkg.insert_log_prc(p_fun_nam   => 'End_Create_Order',
                                      p_inputs    => '',
                                      p_outputs   => to_char(sysdate,
                                                             'YYYYMMDD'),
                                      p_flg_ok    => 1,
                                      p_des_error => null);
    
    commit;*/
  
    --create cod_run
    lv_cod_run := app_lmp_cap_model_pkg.create_cod_run_mas_fun(p_mas_run_id,
                                                               p_num_module,
                                                               p_des);
  
    If lv_cod_run is not null Then
    
      APP_LMP_CAP_TOT_MODEL_PKG.create_model_data_prc(p_cod_run => lv_cod_run);
    
      dbms_output.put_line(lv_cod_run);
      -----
      delete from LMP.LMP_CAP_DBD_INPUTS t
       where t.lkp_typ_dbdin = 'FIX_TON_DAY'
         and cod_run_dbdin = lv_cod_run
         and t.statn_bas_station_id is null;
    
      commit;
    
      select name into lv_connection_server from v$database;
    
      dbms_output.put_line('start run_cap_model_fun ');
      lv_num := APP_LMP_CAP_TOT_MODEL_PKG.run_cap_model_fun(p_cod_run           => lv_cod_run,
                                                            p_connection_server => lv_connection_server,
                                                            p_identifierName    => '1');
    
      commit;
      return lv_num;
    End If;
  end;
  --------------------------- created by s.boosaiedi by request harandi 98/04/04
  Function Get_AAS_For_CAP_Cod_Run_Fun(P_Cod_Run Varchar2) Return Varchar2 Is
    lv_cod_run_mas Varchar2(14);
    lv_mas_id      Number;
    Lv_Cod_Run     Varchar2(14);
  
  Begin
  
    Select m.cod_run_mrhis
      into lv_cod_run_mas
      From mas.Mas_Msch_Run_Histories m
     Where m.msch_run_history_id in
           (select nvl(h.mrhis_msch_run_history_id, 0)
              from lmp.lmp_bas_run_histories h
             where h.cod_run_rnhis = P_Cod_Run);
  
    Lv_Cod_Run := api_mas_models_pkg.Get_AAS_For_MAS_Cod_Run_Fun(P_Cod_Run => lv_cod_run_mas);
  
    return Lv_Cod_Run;
  End;
  --------------------------created by s.boosaiedi 98/04/26
  function ret_run_aas_smp_fun return number is
    lv_flg_assinment number;
  begin
    select fp.VAL_ATT9_LMPFP
      into lv_flg_assinment
      from lmp.lmp_bas_fix_params fp
     where fp.lkp_typ_lmpfp = 'NON_EXECUTE_MODEL';
    return lv_flg_assinment;
  end;
  --------------------------created by s.boosaiedi 98/04/26
  procedure upd_run_aas_smp_prc is
  begin
    update lmp.lmp_bas_fix_params fp
       set fp.val_att9_lmpfp = 1
     where fp.lkp_typ_lmpfp = 'NON_EXECUTE_MODEL';
    commit;
  end;
  --------------------------created by s.boosaiedi 98/05/19
  procedure update_model_stat_step_prc(p_cod_run     in varchar2,
                                       p_cod_mjl_run in varchar2,
                                       p_num_step    in number,
                                       P_NUM_MODULE  IN NUMBER,
                                       p_flg_stat    in number) is
    lv_msg2 varchar2(500);
    lv_msg1 varchar2(500);
    lv_user varchar2(500);
  begin
 
    if (p_flg_stat = 0) then
    
      select fp.val_att3_lmpfp
        into lv_msg2
        from lmp.lmp_bas_fix_params fp
       where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
         and fp.val_att1_lmpfp = 2;
    
      update lmp_bas_model_run_stats S1
         set S1.dat_start_mosta   = sysdate,
             S1.sta_step_mosta    = lv_msg2,
             S1.Cod_Run_Mjl_Mosta = p_cod_mjl_run
       where S1.cod_run_mosta = p_cod_run
         and S1.num_step_mosta = p_num_step
         AND S1.NUM_MODULE_MOSTA = P_NUM_MODULE;
    ELSE
    
      ---update 
      if p_flg_stat = 1 then
        ----successful
        select fp.val_att3_lmpfp
          into lv_msg2
          from lmp.lmp_bas_fix_params fp
         where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
           and fp.val_att1_lmpfp = 3;
      
        update lmp_bas_model_run_stats s1
           set s1.dat_end_mosta = sysdate, s1.sta_step_mosta = lv_msg2
         where s1.cod_run_mosta = p_cod_run
           and (p_cod_mjl_run IS NULL OR
               S1.Cod_Run_Mjl_Mosta = p_cod_mjl_run)
           and s1.num_step_mosta = p_num_step
           AND S1.NUM_MODULE_MOSTA = P_NUM_MODULE;
      else
        ----error
        select fp.val_att3_lmpfp
          into lv_msg2
          from lmp.lmp_bas_fix_params fp
         where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
           and fp.val_att1_lmpfp = 4;
      
        update lmp_bas_model_run_stats s1
           set s1.sta_step_mosta = lv_msg2
         where s1.cod_run_mosta = p_cod_run
           and (p_cod_mjl_run IS NULL OR
               S1.Cod_Run_Mjl_Mosta = p_cod_mjl_run)
           and s1.num_step_mosta = p_num_step
           AND S1.NUM_MODULE_MOSTA = P_NUM_MODULE;
      end if;
    END IF;
  end;

  --------------------------created by s.boosaiedi 98/05/19
  procedure insert_model_stat_step_prc(p_cod_run in varchar2) is
    lv_msg1 varchar2(500);
    lv_msg2 varchar2(500);
  begin
  
    ---num_step :=1   preparing data
    ---num_step :=2   model is running
    ---num_step :=3   insert output
    ---num_step :=4   fill reports
  
    delete from lmp_bas_model_run_stats rs
     where rs.cod_run_mosta = p_cod_run;
  
    ---ASSIGNMENT  num_module_mosta:=10
    select fp.val_att3_lmpfp
      into lv_msg1
      from lmp.lmp_bas_fix_params fp
     where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
       and fp.val_att4_lmpfp = 1;
  
    select fp.val_att3_lmpfp
      into lv_msg2
      from lmp.lmp_bas_fix_params fp
     where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
       and fp.val_att2_lmpfp = 3;
  
    insert into lmp_bas_model_run_stats
      (bas_model_run_stat_id,
       cod_run_mosta,
       des_module_mosta,
       num_step_mosta,
       des_step_mosta,
       num_module_mosta)
    values
      (lmp_bas_model_run_stats_seq.nextval,
       p_cod_run,
       lv_msg1,
       3,
       lv_msg2,
       10);
  
    ---ASSIGNMENT SLAB num_module_mosta:=15
    select fp.val_att3_lmpfp
      into lv_msg1
      from lmp.lmp_bas_fix_params fp
     where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
       and fp.val_att4_lmpfp = 2;
  
    select fp.val_att3_lmpfp
      into lv_msg2
      from lmp.lmp_bas_fix_params fp
     where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
       and fp.val_att2_lmpfp = 3;
  
    insert into lmp_bas_model_run_stats
      (bas_model_run_stat_id,
       cod_run_mosta,
       des_module_mosta,
       num_step_mosta,
       des_step_mosta,
       num_module_mosta)
    values
      (lmp_bas_model_run_stats_seq.nextval,
       p_cod_run,
       lv_msg1,
       3,
       lv_msg2,
       15);
  
    ---MASTER  num_module_mosta:=20
    select fp.val_att3_lmpfp
      into lv_msg1
      from lmp.lmp_bas_fix_params fp
     where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
       and fp.val_att4_lmpfp = 3;
  
    ---- PREPARE DATA  
    select fp.val_att3_lmpfp
      into lv_msg2
      from lmp.lmp_bas_fix_params fp
     where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
       and fp.val_att2_lmpfp = 1;
  
    insert into lmp_bas_model_run_stats
      (bas_model_run_stat_id,
       cod_run_mosta,
       des_module_mosta,
       num_step_mosta,
       des_step_mosta,
       num_module_mosta)
    values
      (lmp_bas_model_run_stats_seq.nextval,
       p_cod_run,
       lv_msg1,
       1,
       lv_msg2,
       20);
  
    ---- READ DATA   
    select fp.val_att3_lmpfp
      into lv_msg2
      from lmp.lmp_bas_fix_params fp
     where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
       and fp.val_att2_lmpfp = 2;
  
    insert into lmp_bas_model_run_stats
      (bas_model_run_stat_id,
       cod_run_mosta,
       des_module_mosta,
       num_step_mosta,
       des_step_mosta,
       num_module_mosta)
    values
      (lmp_bas_model_run_stats_seq.nextval,
       p_cod_run,
       lv_msg1,
       2,
       lv_msg2,
       20);
  
    ---- RUN MODEL  
    select fp.val_att3_lmpfp
      into lv_msg2
      from lmp.lmp_bas_fix_params fp
     where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
       and fp.val_att2_lmpfp = 3;
  
    insert into lmp_bas_model_run_stats
      (bas_model_run_stat_id,
       cod_run_mosta,
       des_module_mosta,
       num_step_mosta,
       des_step_mosta,
       num_module_mosta)
    values
      (lmp_bas_model_run_stats_seq.nextval,
       p_cod_run,
       lv_msg1,
       3,
       lv_msg2,
       20);
  
    ---- INSERT OUTPUT  
    select fp.val_att3_lmpfp
      into lv_msg2
      from lmp.lmp_bas_fix_params fp
     where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
       and fp.val_att2_lmpfp = 4;
  
    insert into lmp_bas_model_run_stats
      (bas_model_run_stat_id,
       cod_run_mosta,
       des_module_mosta,
       num_step_mosta,
       des_step_mosta,
       num_module_mosta)
    values
      (lmp_bas_model_run_stats_seq.nextval,
       p_cod_run,
       lv_msg1,
       4,
       lv_msg2,
       20);
  
    ---CREATE ORDER num_module_mosta:=30
    select fp.val_att3_lmpfp
      into lv_msg1
      from lmp.lmp_bas_fix_params fp
     where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
       and fp.val_att4_lmpfp = 4;
  
    select fp.val_att3_lmpfp
      into lv_msg2
      from lmp.lmp_bas_fix_params fp
     where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
       and fp.val_att2_lmpfp = 3;
  
    insert into lmp_bas_model_run_stats
      (bas_model_run_stat_id,
       cod_run_mosta,
       des_module_mosta,
       num_step_mosta,
       des_step_mosta,
       num_module_mosta)
    values
      (lmp_bas_model_run_stats_seq.nextval,
       p_cod_run,
       lv_msg1,
       3,
       lv_msg2,
       30);
  
    ---CAPACITY PLANNING
    select fp.val_att3_lmpfp
      into lv_msg1
      from lmp.lmp_bas_fix_params fp
     where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
       and fp.val_att4_lmpfp = 5;
  
    ---- PREPARE DATA  
    select fp.val_att3_lmpfp
      into lv_msg2
      from lmp.lmp_bas_fix_params fp
     where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
       and fp.val_att2_lmpfp = 1;
  
    insert into lmp_bas_model_run_stats
      (bas_model_run_stat_id,
       cod_run_mosta,
       des_module_mosta,
       num_step_mosta,
       des_step_mosta,
       num_module_mosta)
    values
      (lmp_bas_model_run_stats_seq.nextval,
       p_cod_run,
       lv_msg1,
       1,
       lv_msg2,
       3);
  
    ---- READ DATA
    select fp.val_att3_lmpfp
      into lv_msg2
      from lmp.lmp_bas_fix_params fp
     where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
       and fp.val_att2_lmpfp = 2;
  
    insert into lmp_bas_model_run_stats
      (bas_model_run_stat_id,
       cod_run_mosta,
       des_module_mosta,
       num_step_mosta,
       des_step_mosta,
       num_module_mosta)
    values
      (lmp_bas_model_run_stats_seq.nextval,
       p_cod_run,
       lv_msg1,
       2,
       lv_msg2,
       3);
  
    ---- RUN MODEL  
    select fp.val_att3_lmpfp
      into lv_msg2
      from lmp.lmp_bas_fix_params fp
     where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
       and fp.val_att2_lmpfp = 3;
  
    insert into lmp_bas_model_run_stats
      (bas_model_run_stat_id,
       cod_run_mosta,
       des_module_mosta,
       num_step_mosta,
       des_step_mosta,
       num_module_mosta)
    values
      (lmp_bas_model_run_stats_seq.nextval,
       p_cod_run,
       lv_msg1,
       3,
       lv_msg2,
       3);
  
    ---- INSERT OUTPUT
    select fp.val_att3_lmpfp
      into lv_msg2
      from lmp.lmp_bas_fix_params fp
     where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
       and fp.val_att2_lmpfp = 4;
  
    insert into lmp_bas_model_run_stats
      (bas_model_run_stat_id,
       cod_run_mosta,
       des_module_mosta,
       num_step_mosta,
       des_step_mosta,
       num_module_mosta)
    values
      (lmp_bas_model_run_stats_seq.nextval,
       p_cod_run,
       lv_msg1,
       4,
       lv_msg2,
       3);
  
    ---- FILL REPORTS
    select fp.val_att3_lmpfp
      into lv_msg2
      from lmp.lmp_bas_fix_params fp
     where fp.lkp_typ_lmpfp = 'CAP_MODEL_STAT'
       and fp.val_att2_lmpfp = 5;
  
    insert into lmp_bas_model_run_stats
      (bas_model_run_stat_id,
       cod_run_mosta,
       des_module_mosta,
       num_step_mosta,
       des_step_mosta,
       num_module_mosta)
    values
      (lmp_bas_model_run_stats_seq.nextval,
       p_cod_run,
       lv_msg1,
       5,
       lv_msg2,
       3);
    COMMIT;
  END;

  --------------------------created by s.boosaiedi 98/05/20

  ----------------------------\\ created by s.saeidi 1399/10/01
  function cal_date_end_model_prc return number is
    lv_dat_end date;
    lv_day     number;
  begin
    execute immediate 'alter session set nls_calendar=persian';
    select to_char(sysdate, 'dd', 'nls_calendar=persian')
      into lv_day
      from dual;
  
    /*if lv_day < 10 then
      select max(v.Dat_Calde)
        into lv_dat_end
        from aac_lmp_calendar_viw v
       where v.v_Dat_Calde_In_6 = to_char(sysdate, 'yyyymm');
    
      return(lv_dat_end - trunc(sysdate) + 1);
    else*/
    
      return 40;
    --end if;
  end;

END APP_LMP_CAP_HEDAYAT_PKG;
