/****************************************************************************
* Program:      ars_tte_production_analysis.sas
* Macro:        %ars_tte_production_analysis
* Purpose:      Run Cox PH + Kaplan-Meier analyses and normalize outputs
*               into ARS-aligned long results (one value per row).
****************************************************************************/

%macro ars_tte_production_analysis(
    adam=,
    out=ars_tte_results_long,
    subject_var=USUBJID,
    trt_var=TRT01A,
    paramcd_var=PARAMCD,
    param_var=PARAM,
    time_var=AVAL,
    censor_var=CNSR,
    censor_value=0,
    class_vars=,
    covariates=,
    alpha=0.05,
    km_timepoint=28,
    where_clause=,
    test_value=,
    ref_value=,
    reporting_event_id=,
    method_id=MTH_COXPH,
    display_id=,
    debug_print=N
);

    %local _where _debug _analysis_id _n_hr _n_meta;
    %let _where=%sysfunc(coalescec(%superq(where_clause),1));
    %let _debug=%upcase(%superq(debug_print));
    %let _analysis_id=AN_TTE_COX_KM;

    %if %superq(adam)= %then %do;
        %put ERROR: ars_tte_production_analysis - ADAM dataset is required.;
        %return;
    %end;

    %if not %sysfunc(exist(&adam)) %then %do;
        %put ERROR: ars_tte_production_analysis - Dataset &adam does not exist.;
        %return;
    %end;

    data &out;
        length source_system $8 reporting_event_id $80 analysis_id $40 method_id $40 operation_id $40 operation_role $20
               parameter_cd $40 parameter $200 avisit $200 treatment $200 contrast $400
               grouping_1_id $40 grouping_1_value $200 grouping_2_id $40 grouping_2_value $200 grouping_3_id $40 grouping_3_value $200
               result_char $200 raw_value $64 formatted_value $200 display_id $80 row_id $80 col_id $80 result_key $1000;
        length avisitn 8 result_numeric 8 result_sequence 8;
        stop;
    run;

    data _tte_in;
        set &adam(where=(&_where));
        length parameter_cd $40 parameter $200;
        parameter_cd=vvalue(&paramcd_var);
        parameter=vvalue(&param_var);
    run;

    proc sort data=_tte_in(keep=parameter_cd parameter) out=_tte_meta nodupkey;
        by parameter_cd parameter;
    run;

    proc sql noprint;
        select count(*) into :_n_meta trimmed from _tte_meta;
    quit;

    %if %superq(_n_meta)=0 %then %do;
        data _tte_meta;
            length parameter_cd $40 parameter $200;
            parameter_cd='';
            parameter='';
            output;
        run;
    %end;

    proc means data=_tte_in noprint;
        class &trt_var;
        var &time_var;
        output out=_tte_desc(drop=_type_ _freq_)
            n=n mean=mean std=sd median=median min=min max=max;
    run;

    data _tte_desc;
        set _tte_desc;
        where not missing(&trt_var);
        length operation_id $40;
        operation_id='OP_TTE_DESC';
    run;

    proc sql;
        create table _tte_censor as
        select &trt_var,
               sum(case when &censor_var=&censor_value then 1 else 0 end) as n_censored,
               count(*) as n_total
        from _tte_in
        group by &trt_var;
    quit;

    data _tte_censor;
        set _tte_censor;
        pct_censored=100*n_censored/max(n_total,1);
        length operation_id $40;
        operation_id='OP_TTE_CENSOR';
    run;

    ods exclude all;
    ods output Quartiles=_tte_quartile_raw ProductLimitEstimates=_tte_ple;
    proc lifetest data=_tte_in method=km alpha=&alpha timelist=&km_timepoint;
        time &time_var*&censor_var(&censor_value);
        strata &trt_var;
    run;
    ods output close;
    ods exclude none;

    %if not %sysfunc(exist(_tte_hr)) %then %do;
        data _tte_hr;
            length Comparison Description Label Effect $400 HazardRatio HRLowerCL HRUpperCL 8;
            stop;
        run;
    %end;

    %if not %sysfunc(exist(_tte_type3)) %then %do;
        data _tte_type3;
            length Effect $200 ProbChiSq 8;
            stop;
        run;
    %end;

    %if %sysfunc(exist(_tte_quartile_raw)) %then %do;
        data _tte_quartile;
            set _tte_quartile_raw;
            where Percent=50;
            length operation_id $40 trt_value $200;
            operation_id='OP_TTE_KM_MEDIAN';
            trt_value=coalescec(strip(vvaluex("&trt_var")), strip(scan(Stratum,2,'=')));
            median_est=Estimate;
            median_lcl=LowerLimit;
            median_ucl=UpperLimit;
        run;
    %end;
    %else %do;
        data _tte_quartile;
            length trt_value $200 operation_id $40 median_est median_lcl median_ucl 8;
            stop;
        run;
    %end;

    %if %sysfunc(exist(_tte_ple)) %then %do;
        data _tte_ple_day;
            set _tte_ple;
            where &time_var <= &km_timepoint;
            length trt_value $200;
            trt_value=coalescec(strip(vvaluex("&trt_var")), strip(scan(Stratum,2,'=')));
            keep trt_value &time_var Survival;
        run;

        proc sort data=_tte_ple_day;
            by trt_value &time_var;
        run;

        data _tte_timelist;
            set _tte_ple_day;
            by trt_value &time_var;
            if last.trt_value;
            length operation_id $40;
            operation_id='OP_TTE_KM_CINC';
            cum_inc=100*(1-Survival);
            keep trt_value operation_id cum_inc;
        run;
    %end;
    %else %do;
        data _tte_timelist;
            length trt_value $200 operation_id $40 cum_inc 8;
            stop;
        run;
    %end;

    ods exclude all;
    ods output HazardRatios=_tte_hr Type3=_tte_type3;
    proc phreg data=_tte_in;
        class &trt_var (ref="%superq(ref_value)") &class_vars / param=ref;
        model &time_var*&censor_var(&censor_value) = &trt_var &covariates / rl alpha=&alpha;
        hazardratio &trt_var / diff=ref cl=wald;
    run;
    ods output close;
    ods exclude none;

    %if %superq(test_value)= or %superq(ref_value)= %then %do;
        %put ERROR: ars_tte_production_analysis - TEST_VALUE and REF_VALUE are required to identify the HR contrast.;
        %return;
    %end;

    %if %superq(test_value) ne and %superq(ref_value) ne %then %do;
        data _tte_hr;
            set _tte_hr;
            length _cmp $400;
            _cmp=upcase(compbl(coalescec(Comparison, Description, Label, Effect)));
            if index(_cmp, upcase(strip("%superq(test_value)")))=0 then delete;
            if index(_cmp, upcase(strip("%superq(ref_value)")))=0 then delete;
        run;
    %end;

    proc sql noprint;
        select count(*) into :_n_hr trimmed from _tte_hr;
    quit;

    %if %superq(_n_hr) ne 1 %then %do;
        %put ERROR: ars_tte_production_analysis - Expected exactly 1 HR row for %superq(test_value) vs %superq(ref_value), found &_n_hr..;
        %return;
    %end;

    data _tte_hr_one;
        set _tte_hr;
        length operation_id $40 contrast $400;
        length _vname $64 _cval $200;
        operation_id='OP_TTE_COX_HR';
        contrast=coalescec(Comparison, Description, Label, Effect);
        hr=coalesce(HazardRatio, PointEstimate, Estimate);
        lcl=coalesce(HRLowerCL, LowerWaldCL, LowerCL);
        ucl=coalesce(HRUpperCL, UpperWaldCL, UpperCL);

        array _nums _numeric_;
        array _chars _character_;
        do _i=1 to dim(_nums);
            _vname=upcase(vname(_nums[_i]));

            if missing(hr) then do;
                if index(_vname,'HAZARDRATIO')>0 or index(_vname,'POINTESTIMATE')>0 then hr=_nums[_i];
            end;

            if missing(lcl) then do;
                if index(_vname,'LOWER')>0 and (index(_vname,'CL')>0 or index(_vname,'LIMIT')>0) then lcl=_nums[_i];
            end;

            if missing(ucl) then do;
                if index(_vname,'UPPER')>0 and (index(_vname,'CL')>0 or index(_vname,'LIMIT')>0) then ucl=_nums[_i];
            end;
        end;

        do _j=1 to dim(_chars);
            _vname=upcase(vname(_chars[_j]));
            _cval=strip(_chars[_j]);
            _nval=input(_cval,?? best32.);

            if missing(hr) and not missing(_nval) then do;
                if index(_vname,'HAZARDRATIO')>0 or index(_vname,'POINTESTIMATE')>0 then hr=_nval;
            end;

            if missing(lcl) and not missing(_nval) then do;
                if index(_vname,'LOWER')>0 and (index(_vname,'CL')>0 or index(_vname,'LIMIT')>0) then lcl=_nval;
            end;

            if missing(ucl) and not missing(_nval) then do;
                if index(_vname,'UPPER')>0 and (index(_vname,'CL')>0 or index(_vname,'LIMIT')>0) then ucl=_nval;
            end;
        end;

        /* Final heuristic fallback:
           if CI still missing, infer bounds from numeric values surrounding HR */
        if not missing(hr) and (missing(lcl) or missing(ucl)) then do;
            _lcand=.;
            _ucand=.;
            do _k=1 to dim(_nums);
                _x=_nums[_k];
                if not missing(_x) and _x>0 and _x<=100 then do;
                    if _x<hr then _lcand=max(_lcand,_x);
                    else if _x>hr then do;
                        if missing(_ucand) then _ucand=_x;
                        else _ucand=min(_ucand,_x);
                    end;
                end;
            end;
            if missing(lcl) then lcl=_lcand;
            if missing(ucl) then ucl=_ucand;
        end;
        drop _i _j _k _vname _cval _nval _x _lcand _ucand;
    run;

    data _tte_pval;
        set _tte_type3;
        where upcase(strip(Effect))=upcase(strip("&trt_var"));
        length operation_id $40;
        operation_id='OP_TTE_COX_HR';
        pval=ProbChiSq;
        keep operation_id pval;
    run;

    proc sql;
        create table _tte_hr_all as
        select a.operation_id, a.contrast, a.hr, a.lcl, a.ucl, b.pval
        from _tte_hr_one as a
        left join _tte_pval as b
        on 1=1;
    quit;

    data _tte_long_desc;
        if _n_=1 then set _tte_meta(obs=1);
        set _tte_desc;
        length source_system $8 reporting_event_id $80 analysis_id $40 method_id $40 operation_id $40 operation_role $20
               parameter_cd $40 parameter $200 avisit $200 treatment $200 contrast $400
               grouping_1_id $40 grouping_1_value $200 grouping_2_id $40 grouping_2_value $200 grouping_3_id $40 grouping_3_value $200
               result_char $200 raw_value $64 formatted_value $200 display_id $80 row_id $80 col_id $80 result_key $1000;
        length avisitn 8 result_numeric 8 result_sequence 8;

        array _vals[6] n mean sd median min max;
        array _roles[6] $20 _temporary_ ('N','MEAN','SD','MEDIAN','MIN','MAX');

        do _i=1 to dim(_vals);
            source_system='SAS';
            reporting_event_id="%superq(reporting_event_id)";
            analysis_id="&_analysis_id";
            method_id="%superq(method_id)";
            operation_id='OP_TTE_DESC';
            operation_role=_roles[_i];
            treatment=vvalue(&trt_var);
            result_numeric=_vals[_i];
            raw_value=strip(put(result_numeric,best32.));
            formatted_value=raw_value;
            display_id="%superq(display_id)";
            result_key=catx('|',analysis_id,operation_id,operation_role,parameter_cd,treatment,put(_i,8.));
            output;
        end;
        keep source_system reporting_event_id analysis_id method_id operation_id operation_role
             parameter_cd parameter avisit avisitn treatment contrast
             grouping_1_id grouping_1_value grouping_2_id grouping_2_value grouping_3_id grouping_3_value
             result_numeric result_char raw_value formatted_value
             display_id row_id col_id result_key result_sequence;
    run;

    data _tte_long_censor;
        if _n_=1 then set _tte_meta(obs=1);
        set _tte_censor;
        length source_system $8 reporting_event_id $80 analysis_id $40 method_id $40 operation_id $40 operation_role $20
               parameter_cd $40 parameter $200 avisit $200 treatment $200 contrast $400
               grouping_1_id $40 grouping_1_value $200 grouping_2_id $40 grouping_2_value $200 grouping_3_id $40 grouping_3_value $200
               result_char $200 raw_value $64 formatted_value $200 display_id $80 row_id $80 col_id $80 result_key $1000;
        length avisitn 8 result_numeric 8 result_sequence 8;

        do operation_role='N_CENS','PCT_CENS';
            source_system='SAS';
            reporting_event_id="%superq(reporting_event_id)";
            analysis_id="&_analysis_id";
            method_id="%superq(method_id)";
            operation_id='OP_TTE_CENSOR';
            treatment=vvalue(&trt_var);
            if operation_role='N_CENS' then result_numeric=n_censored;
            else result_numeric=pct_censored;
            raw_value=strip(put(result_numeric,best32.));
            formatted_value=raw_value;
            display_id="%superq(display_id)";
            result_key=catx('|',analysis_id,operation_id,operation_role,treatment);
            output;
        end;
        keep source_system reporting_event_id analysis_id method_id operation_id operation_role
             parameter_cd parameter avisit avisitn treatment contrast
             grouping_1_id grouping_1_value grouping_2_id grouping_2_value grouping_3_id grouping_3_value
             result_numeric result_char raw_value formatted_value
             display_id row_id col_id result_key result_sequence;
    run;

    data _tte_long_km;
        if _n_=1 then set _tte_meta(obs=1);
        set _tte_quartile(in=inmed) _tte_timelist(in=intime);
        length source_system $8 reporting_event_id $80 analysis_id $40 method_id $40 operation_id $40 operation_role $20
               parameter_cd $40 parameter $200 avisit $200 treatment $200 contrast $400
               grouping_1_id $40 grouping_1_value $200 grouping_2_id $40 grouping_2_value $200 grouping_3_id $40 grouping_3_value $200
               result_char $200 raw_value $64 formatted_value $200 display_id $80 row_id $80 col_id $80 result_key $1000;
        length avisitn 8 result_numeric 8 result_sequence 8;

        source_system='SAS';
        reporting_event_id="%superq(reporting_event_id)";
        analysis_id="&_analysis_id";
        method_id="%superq(method_id)";
        treatment=coalescec(strip(vvaluex("&trt_var")),strip(trt_value));
        display_id="%superq(display_id)";

        if inmed then do;
            operation_id='OP_TTE_KM_MEDIAN';
            do operation_role='ESTIMATE','LCL','UCL';
                if operation_role='ESTIMATE' then result_numeric=median_est;
                else if operation_role='LCL' then result_numeric=median_lcl;
                else if operation_role='UCL' then result_numeric=median_ucl;
                raw_value=strip(put(result_numeric,best32.));
                formatted_value=raw_value;
                result_key=catx('|',analysis_id,operation_id,operation_role,treatment);
                output;
            end;
        end;
        else if intime then do;
            operation_id='OP_TTE_KM_CINC';
            operation_role='PCT';
            result_numeric=cum_inc;
            raw_value=strip(put(result_numeric,best32.));
            formatted_value=raw_value;
            result_key=catx('|',analysis_id,operation_id,operation_role,treatment);
            output;
        end;

        keep source_system reporting_event_id analysis_id method_id operation_id operation_role
             parameter_cd parameter avisit avisitn treatment contrast
             grouping_1_id grouping_1_value grouping_2_id grouping_2_value grouping_3_id grouping_3_value
             result_numeric result_char raw_value formatted_value
             display_id row_id col_id result_key result_sequence;
    run;

    data _tte_long_hr;
        if _n_=1 then set _tte_meta(obs=1);
        set _tte_hr_all;
        length source_system $8 reporting_event_id $80 analysis_id $40 method_id $40 operation_id $40 operation_role $20
               parameter_cd $40 parameter $200 avisit $200 treatment $200 contrast $400
               grouping_1_id $40 grouping_1_value $200 grouping_2_id $40 grouping_2_value $200 grouping_3_id $40 grouping_3_value $200
               result_char $200 raw_value $64 formatted_value $200 display_id $80 row_id $80 col_id $80 result_key $1000;
        length avisitn 8 result_numeric 8 result_sequence 8;

        source_system='SAS';
        reporting_event_id="%superq(reporting_event_id)";
        analysis_id="&_analysis_id";
        method_id="%superq(method_id)";
        operation_id='OP_TTE_COX_HR';
        display_id="%superq(display_id)";

        do operation_role='ESTIMATE','LCL','UCL','PVALUE';
            if operation_role='ESTIMATE' then result_numeric=hr;
            else if operation_role='LCL' then result_numeric=lcl;
            else if operation_role='UCL' then result_numeric=ucl;
            else if operation_role='PVALUE' then result_numeric=pval;
            raw_value=strip(put(result_numeric,best32.));
            formatted_value=raw_value;
            result_key=catx('|',analysis_id,operation_id,operation_role,coalescec(contrast,''));
            output;
        end;

        keep source_system reporting_event_id analysis_id method_id operation_id operation_role
             parameter_cd parameter avisit avisitn treatment contrast
             grouping_1_id grouping_1_value grouping_2_id grouping_2_value grouping_3_id grouping_3_value
             result_numeric result_char raw_value formatted_value
             display_id row_id col_id result_key result_sequence;
    run;

    data &out;
        set _tte_long_desc _tte_long_censor _tte_long_km _tte_long_hr;
    run;

    %if &_debug ne Y %then %do;
        proc datasets lib=work nolist;
            delete _tte_in _tte_desc _tte_censor _tte_quartile_raw _tte_ple _tte_ple_day _tte_quartile _tte_timelist
                   _tte_hr _tte_type3 _tte_hr_one _tte_pval _tte_hr_all
                   _tte_long_desc _tte_long_censor _tte_long_km _tte_long_hr _tte_meta;
        quit;
    %end;

%mend ars_tte_production_analysis;
