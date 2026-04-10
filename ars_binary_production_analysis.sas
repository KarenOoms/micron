/****************************************************************************
* Program:      ars_binary_production_analysis.sas
* Macro:        %ars_binary_production_analysis
* Purpose:      Run Fisher's exact test for binary endpoints and normalize
*               outputs into ARS-like long format.
****************************************************************************/

%macro ars_binary_production_analysis(
    adam=,
    out=ars_binary_results_long,
    subject_var=USUBJID,
    trt_var=TRT01A,
    paramcd_var=PARAMCD,
    param_var=PARAM,
    resp_var=AVALC,
    event_value=Y,
    non_event_value=N,
    missing_label=Missing,
    where_clause=,
    test_value=,
    ref_value=,
    reporting_event_id=,
    method_id=MTH_FISHER,
    display_id=,
    debug_print=N
);

    %local _where _debug _analysis_id _n_trt_levels _dsid _varnum _rc;
    %let _where=%sysfunc(coalescec(%superq(where_clause),1));
    %let _debug=%upcase(%superq(debug_print));
    %let _analysis_id=AN_BINARY_FISHER;

    %if %superq(adam)= or not %sysfunc(exist(&adam)) %then %do;
        %put ERROR: ars_binary_production_analysis - ADAM dataset is required and must exist.;
        %return;
    %end;

    %let _dsid=%sysfunc(open(&adam,i));
    %if &_dsid=0 %then %do;
        %put ERROR: ars_binary_production_analysis - Unable to open ADAM dataset &adam..;
        %return;
    %end;
    %let _varnum=%sysfunc(varnum(&_dsid,%superq(resp_var)));
    %let _rc=%sysfunc(close(&_dsid));
    %if &_varnum=0 %then %do;
        %put ERROR: ars_binary_production_analysis - RESP_VAR=%superq(resp_var) was not found in &adam..;
        %put ERROR: ars_binary_production_analysis - Check that RESP_VAR is passed as a variable name (for example RESP_VAR=ORGA28, not RESP_VAR=resp_var).;
        %return;
    %end;

    data _bin_in;
        set &adam(where=(&_where));
        length parameter_cd $40 parameter $200 resp_cat $40;
        parameter_cd=vvalue(&paramcd_var);
        parameter=vvalue(&param_var);

        if missing(&resp_var) then resp_cat='MISSING';
        else if upcase(strip(vvalue(&resp_var)))=upcase(strip("%superq(event_value)")) then resp_cat='EVENT';
        else if upcase(strip(vvalue(&resp_var)))=upcase(strip("%superq(non_event_value)")) then resp_cat='NON_EVENT';
        else resp_cat='NON_EVENT';
    run;

    proc sort data=_bin_in(keep=parameter_cd parameter) out=_bin_meta nodupkey;
        by parameter_cd parameter;
    run;

    proc sql;
        create table _bin_n as
        select &trt_var, count(*) as n_denom
        from _bin_in
        group by &trt_var;

        create table _bin_cnt as
        select &trt_var, resp_cat, count(*) as n
        from _bin_in
        group by &trt_var, resp_cat;

        create table _bin_cnt2 as
        select a.&trt_var, a.resp_cat, a.n, b.n_denom,
               100*a.n/max(b.n_denom,1) as pct
        from _bin_cnt as a
        left join _bin_n as b
          on a.&trt_var=b.&trt_var;
    quit;

    proc sql noprint;
        select count(distinct &trt_var) into :_n_trt_levels trimmed
        from _bin_in
        where resp_cat in ('EVENT','NON_EVENT');
    quit;

    ods exclude all;
    %if %superq(_n_trt_levels)=2 %then %do;
        ods output FishersExact=_bin_fisher
                   RelativeRisks   = _bin_or
                   OddsRatioExactCL=_bin_or_exact;
    %end;
    %else %do;
        ods output FishersExact=_bin_fisher
                   OddsRatioExactCL=_bin_or_exact;
    %end;
    proc freq data=_bin_in;
        tables &trt_var*resp_cat / fisher relrisk;
        exact or;
        where resp_cat in ('EVENT','NON_EVENT');
    run;
    ods output close;
    ods exclude none;

    %if not %sysfunc(exist(_bin_fisher)) %then %do;
        data _bin_fisher;
            length Name1 $80 cValue1 $200 nValue1 8;
            stop;
        run;
    %end;

    %if not %sysfunc(exist(_bin_or)) %then %do;
        data _bin_or;
            length OddsRatioEst OddsRatio LowerCL UpperCL 8;
            stop;
        run;
    %end;

    %if not %sysfunc(exist(_bin_or_exact)) %then %do;
        data _bin_or_exact;
            length OddsRatioEst OddsRatio LowerCL UpperCL 8;
            stop;
        run;
    %end;

    data _bin_or_pool;
        set _bin_or _bin_or_exact;
    run;

    data _bin_or1;
        set _bin_or_pool;
        length or_est or_lcl or_ucl 8;
        length _vname $64;
        or_est=coalesce(OddsRatioEst,OddsRatio,Value,Estimate);
        or_lcl=coalesce(LowerCL,Lower,LowerLimit);
        or_ucl=coalesce(UpperCL,Upper,UpperLimit);

        array _nums _numeric_;
        do _i=1 to dim(_nums);
            _vname=upcase(vname(_nums[_i]));
            if missing(or_est) and (index(_vname,'ODDSRATIO')>0 or index(_vname,'ESTIMATE')>0) then or_est=_nums[_i];
            if missing(or_lcl) and index(_vname,'LOWER')>0 and (index(_vname,'CL')>0 or index(_vname,'LIMIT')>0) then or_lcl=_nums[_i];
            if missing(or_ucl) and index(_vname,'UPPER')>0 and (index(_vname,'CL')>0 or index(_vname,'LIMIT')>0) then or_ucl=_nums[_i];
        end;

        drop _i _vname;
        keep or_est or_lcl or_ucl;
    run;

    proc sql noprint;
        create table _bin_p as
        select max(nValue1) as pval
        from _bin_fisher
        where upcase(coalescec(Name1,'')) in ('XP2_FISH','P_TABLE');
    quit;

    proc sql;
        create table _bin_orall as
        select a.or_est, a.or_lcl, a.or_ucl, b.pval
        from (select * from _bin_or1(obs=1)) as a
        left join _bin_p as b
        on 1=1;
    quit;

    data _bin_long_cnt;
        if _n_=1 then set _bin_meta(obs=1);
        set _bin_cnt2;
        length source_system $8 reporting_event_id $80 analysis_id $40 method_id $40 operation_id $40 operation_role $20
               parameter_cd $40 parameter $200 treatment $200 result_char $200 raw_value $64 formatted_value $200
               display_id $80 result_key $1000 grouping_1_id $40 grouping_1_value $200;
        length result_numeric 8;

        source_system='SAS';
        reporting_event_id="%superq(reporting_event_id)";
        analysis_id="&_analysis_id";
        method_id="%superq(method_id)";
        operation_id='OP_BIN_COUNT_PCT';
        treatment=vvalue(&trt_var);
        grouping_1_id='RESP_CAT';
        grouping_1_value=resp_cat;
        display_id="%superq(display_id)";

        do operation_role='COUNT','PCT';
            if operation_role='COUNT' then result_numeric=n;
            else result_numeric=pct;
            raw_value=strip(put(result_numeric,best32.));
            formatted_value=raw_value;
            result_key=catx('|',analysis_id,operation_id,operation_role,treatment,grouping_1_value);
            output;
        end;

        keep source_system reporting_event_id analysis_id method_id operation_id operation_role
             parameter_cd parameter treatment grouping_1_id grouping_1_value
             result_numeric result_char raw_value formatted_value display_id result_key;
    run;

    data _bin_long_or;
        if _n_=1 then set _bin_meta(obs=1);
        set _bin_orall;
        length source_system $8 reporting_event_id $80 analysis_id $40 method_id $40 operation_id $40 operation_role $20
               parameter_cd $40 parameter $200 treatment $200 contrast $400 result_char $200 raw_value $64 formatted_value $200
               display_id $80 result_key $1000;
        length result_numeric 8;

        source_system='SAS';
        reporting_event_id="%superq(reporting_event_id)";
        analysis_id="&_analysis_id";
        method_id="%superq(method_id)";
        operation_id='OP_BIN_OR';
        contrast=cats("%superq(test_value)",' vs ',"%superq(ref_value)");
        display_id="%superq(display_id)";

        do operation_role='ESTIMATE','LCL','UCL','PVALUE';
            if operation_role='ESTIMATE' then result_numeric=or_est;
            else if operation_role='LCL' then result_numeric=or_lcl;
            else if operation_role='UCL' then result_numeric=or_ucl;
            else result_numeric=pval;
            raw_value=strip(put(result_numeric,best32.));
            formatted_value=raw_value;
            result_key=catx('|',analysis_id,operation_id,operation_role,contrast);
            output;
        end;

        keep source_system reporting_event_id analysis_id method_id operation_id operation_role
             parameter_cd parameter treatment contrast
             result_numeric result_char raw_value formatted_value display_id result_key;
    run;

    data &out;
        set _bin_long_cnt _bin_long_or;
    run;

%mend ars_binary_production_analysis;
