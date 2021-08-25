FUNCTION run_cap_model_fun(
  p_connection_server IN VARCHAR2,
  p_identifierName IN VARCHAR2
) RETURN NUMBER IS
  lv_envelope clob;
  lv_xml xmltype;
  lv_output VARCHAR2(10000);

  BEGIN
 
    lv_envelope := '<?xml version="1.0" encoding="UTF-8"?>
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tem="http://tempuri.org/">
      <soapenv:Header/>
      <soapenv:Body>
          <tem:ExecuteModel>
            <tem:codRun>' || code_run_global_variable || '</tem:codRun>
            <tem:connectionServer>' || p_connection_server || '</tem:connectionServer>
            <tem:identifierName>' || p_identifierName || '</tem:identifierName>
          </tem:ExecuteModel>
      </soapenv:Body>
    </soapenv:Envelope>';

    fnd.fnd_call_soap_web_srv_prc(
      CONTENT = > lv_envelope,
      URL = > 'http://services.msc.ir/osb/LMPCAP/CapacityPlanningService/ExecuteModel',
      P_OUT_PUT = > lv_output
    );


    app_lmp_global_pkg.insert_log_prc(
      p_fun_nam = > 'APP_LMP_SOP_MODEL_PKG.RUN_SOP_MODEL_FUN',
      p_inputs = > 'fnd_call_soap_web_srv_prc is ended',
      p_outputs = > to_char(
        SYSDATE,
        'YYYYMMDD'
      ),
      p_flg_ok = > 1,
      p_des_error = > lv_output
    );

    RETURN 1;

    EXCEPTION
      WHEN OTHERS THEN RETURN 0;

END;