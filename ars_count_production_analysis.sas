/****************************************************************************
* Program:      ars_count_production_analysis.sas
* Macro:        %ars_count_production_analysis
* Purpose:      Run WMW/Hodges-Lehmann and build normalized long output for
*               count-style endpoints (OSFD/RSFD/IMV-ECMO free days, etc.).
****************************************************************************/

%macro ars_count_production_analysis(
    adam=,
    out=ars_count_results_long,
    subject_var=USUBJID,
    trt_var=TRT01A,
    paramcd_var=PARAMCD,
    param_var=PARAM,
    aval_var=AVAL,
    death_var=,
    withdraw_var=,
    where_clause=,
    test_value=,
    ref_value=,
    reporting_event_id=,
    method_id=MTH_WMW,
    display_id=,
    debug_print=N
);

    %local _where _debug _analysis_id _n_anl _n_levels _dsid _varnum _rc;
    %let _where=%sysfunc(coalescec(%superq(where_clause),1));
    %let _debug=%upcase(%superq(debug_print));
    %let _analysis_id=AN_COUNT_WMW;

    %if %superq(adam)= or not %sysfunc(exist(&adam)) %then %do;
        %put ERROR: ars_count_production_analysis - ADAM dataset is required and must exist.;
        %return;
    %end;

    %let _dsid=%sysfunc(open(&adam,i));
    %if &_dsid=0 %then %do;
        %put ERROR: ars_count_production_analysis - Unable to open ADAM dataset &adam..;
        %return;
    %end;

    %let _varnum=%sysfunc(varnum(&_dsid,%superq(trt_var)));
    %if &_varnum=0 %then %do;
        %let _rc=%sysfunc(close(&_dsid));
        %put ERROR: ars_count_production_analysis - TRT_VAR=%superq(trt_var) was not found in &adam..;
        %return;
    %end;

    %let _varnum=%sysfunc(varnum(&_dsid,%superq(aval_var)));
    %if &_varnum=0 %then %do;
        %let _rc=%sysfunc(close(&_dsid));
        %put ERROR: ars_count_production_analysis - AVAL_VAR=%superq(aval_var) was not found in &adam..;
        %return;
    %end;

    %let _varnum=%sysfunc(varnum(&_dsid,%superq(paramcd_var)));
    %if &_varnum=0 %then %do;
        %let _rc=%sysfunc(close(&_dsid));
        %put ERROR: ars_count_production_analysis - PARAMCD_VAR=%superq(paramcd_var) was not found in &adam..;
        %return;
    %end;

    %let _varnum=%sysfunc(varnum(&_dsid,%superq(param_var)));
    %if &_varnum=0 %then %do;
        %let _rc=%sysfunc(close(&_dsid));
        %put ERROR: ars_count_production_analysis - PARAM_VAR=%superq(param_var) was not found in &adam..;
        %return;
    %end;

    %if %superq(death_var) ne %then %do;
        %let _varnum=%sysfunc(varnum(&_dsid,%superq(death_var)));
        %if &_varnum=0 %then %do;
            %let _rc=%sysfunc(close(&_dsid));
            %put ERROR: ars_count_production_analysis - DEATH_VAR=%superq(death_var) was not found in &adam..;
            %return;
        %end;
    %end;

    %if %superq(withdraw_var) ne %then %do;
        %let _varnum=%sysfunc(varnum(&_dsid,%superq(withdraw_var)));
        %if &_varnum=0 %then %do;
            %let _rc=%sysfunc(close(&_dsid));
            %put ERROR: ars_count_production_analysis - WITHDRAW_VAR=%superq(withdraw_var) was not found in &adam..;
            %return;
        %end;
    %end;

    %let _rc=%sysfunc(close(&_dsid));

    data _cnt_in;
        set &adam(where=(&_where));
        length parameter_cd $40 parameter $200 _trt $200;
        parameter_cd=vvalue(&paramcd_var);
        parameter=vvalue(&param_var);
        _trt=vvalue(&trt_var);
        _grp=.;
        if upcase(strip(_trt))=upcase(strip("%superq(test_value)")) then _grp=1;
        else if upcase(strip(_trt))=upcase(strip("%superq(ref_value)")) then _grp=2;
        _aval=&aval_var;
        _is_death=0;
        _is_withdraw=0;
        %if %superq(death_var) ne %then %do;
            if upcase(strip(vvalue(&death_var))) in ('Y','YES','1','TRUE') then _is_death=1;
        %end;
        %if %superq(withdraw_var) ne %then %do;
            if upcase(strip(vvalue(&withdraw_var))) in ('Y','YES','1','TRUE') then _is_withdraw=1;
        %end;
    run;

    proc means data=_cnt_in noprint;
        class _trt;
        var _aval;
        output out=_cnt_stats(drop=_type_ _freq_)
            n=n
            mean=mean
            std=std
            median=median
            q1=q1
            q3=q3
            min=min
            max=max;
    run;

    data _cnt_stats2;
        set _cnt_stats;
        length treatment $200;
        if missing(_trt) then treatment='Total';
        else treatment=_trt;
    run;

    proc sql;
        create table _cnt_n as
        select treatment, max(n) as n_denom
        from _cnt_stats2
        group by treatment;

        create table _cnt_death as
        select case when missing(_trt) then 'Total' else _trt end as treatment length=200,
               sum(_is_death) as n
        from _cnt_in
        group by _trt
        union corr
        select 'Total' as treatment length=200,
               sum(_is_death) as n
        from _cnt_in;

        create table _cnt_withdraw as
        select case when missing(_trt) then 'Total' else _trt end as treatment length=200,
               sum(_is_withdraw) as n
        from _cnt_in
        group by _trt
        union corr
        select 'Total' as treatment length=200,
               sum(_is_withdraw) as n
        from _cnt_in;
    quit;

    proc sql;
        create table _cnt_death2 as
        select a.treatment, a.n, b.n_denom,
               100*a.n/max(b.n_denom,1) as pct
        from _cnt_death a left join _cnt_n b
        on a.treatment=b.treatment;

        create table _cnt_withdraw2 as
        select a.treatment, a.n, b.n_denom,
               100*a.n/max(b.n_denom,1) as pct
        from _cnt_withdraw a left join _cnt_n b
        on a.treatment=b.treatment;
    quit;

    proc sql noprint;
        select count(*) into :_n_anl trimmed
        from _cnt_in
        where _grp in (1,2)
          and not missing(_grp)
          and not missing(_aval);

        select count(distinct _grp) into :_n_levels trimmed
        from _cnt_in
        where _grp in (1,2)
          and not missing(_grp)
          and not missing(_aval);
    quit;

    %if %sysevalf(%superq(_n_anl)>0) and %sysevalf(%superq(_n_levels)>=2) %then %do;
        ods exclude all;
        ods output WilcoxonTest=_cnt_wmw
                   HodgesLehmann=_cnt_hl
                   HL=_cnt_hl_alt1
                   MedianScores=_cnt_hl_alt2
                   ConfLimits=_cnt_hl_alt3;
        proc npar1way data=_cnt_in wilcoxon hl;
            class _grp;
            var _aval;
            where _grp in (1,2)
              and not missing(_grp)
              and not missing(_aval);
        run;
        ods output close;
        ods exclude none;
    %end;
    %else %do;
        %put NOTE: ars_count_production_analysis - No analyzable records for WMW/HL (N=&_n_anl, class levels=&_n_levels).;
    %end;

    %if not %sysfunc(exist(_cnt_wmw)) %then %do;
        data _cnt_wmw;
            length Name1 $80 cValue1 $200 nValue1 8;
            stop;
        run;
    %end;

    %if %sysfunc(exist(_cnt_hl_alt1)) %then %do;
        proc append base=_cnt_hl data=_cnt_hl_alt1 force; run;
    %end;

    %if %sysfunc(exist(_cnt_hl_alt2)) %then %do;
        proc append base=_cnt_hl data=_cnt_hl_alt2 force; run;
    %end;

    %if %sysfunc(exist(_cnt_hl_alt3)) %then %do;
        proc append base=_cnt_hl data=_cnt_hl_alt3 force; run;
    %end;

    %if not %sysfunc(exist(_cnt_hl)) %then %do;
        data _cnt_hl;
            length Estimate LowerCL UpperCL 8;
            stop;
        run;
    %end;

    data _cnt_p;
        length pval 8 _vname $64;
        pval=.;
        do until(_eof);
            set _cnt_wmw end=_eof;
            array _nums _numeric_;
            do _i=1 to dim(_nums);
                _vname=upcase(vname(_nums[_i]));
                if index(_vname,'P')>0 and 0<=_nums[_i]<=1 then pval=_nums[_i];
                else if missing(pval) and index(_vname,'PROB')>0 and 0<=_nums[_i]<=1 then pval=_nums[_i];
                else if missing(pval) and index(_vname,'PVALUE')>0 and 0<=_nums[_i]<=1 then pval=_nums[_i];
            end;
        end;
        output;
        keep pval;
    run;

    data _cnt_hl1;
        length est lcl ucl 8 _vname $64;
        est=.; lcl=.; ucl=.;
        do until(_eof);
            set _cnt_hl end=_eof;
            array _nums _numeric_;
            do _i=1 to dim(_nums);
                _vname=upcase(vname(_nums[_i]));
                if missing(est) and (index(_vname,'EST')>0 or index(_vname,'HODGES')>0 or index(_vname,'HL')>0 or index(_vname,'LOCATION')>0 or index(_vname,'SHIFT')>0) then est=_nums[_i];
                if missing(lcl) and index(_vname,'LOW')>0 and (index(_vname,'CL')>0 or index(_vname,'LIMIT')>0) then lcl=_nums[_i];
                if missing(ucl) and index(_vname,'UPP')>0 and (index(_vname,'CL')>0 or index(_vname,'LIMIT')>0) then ucl=_nums[_i];
            end;
        end;
        output;
        keep est lcl ucl;
    run;

    proc sql;
        create table _cnt_cmp as
        select a.est, a.lcl, a.ucl, b.pval
        from (select * from _cnt_hl1(obs=1)) a
        left join _cnt_p b on 1=1;
    quit;

    proc sort data=_cnt_in(keep=parameter_cd parameter) out=_cnt_meta nodupkey;
        by parameter_cd parameter;
    run;

    data _cnt_long_stats;
        if _n_=1 then set _cnt_meta(obs=1);
        set _cnt_stats2;
        length source_system $8 reporting_event_id $80 analysis_id $40 method_id $40 operation_id $40 operation_role $20
               parameter_cd $40 parameter $200 treatment $200 result_char $200 raw_value $64 formatted_value $200
               display_id $80 result_key $1000;
        length result_numeric 8;

        source_system='SAS';
        reporting_event_id="%superq(reporting_event_id)";
        analysis_id="&_analysis_id";
        method_id="%superq(method_id)";
        operation_id='OP_CNT_DESC';
        display_id="%superq(display_id)";
        result_char='';

        do operation_role='N','MEAN','SD','MEDIAN','Q1','Q3','MIN','MAX';
            select (operation_role);
                when ('N') result_numeric=n;
                when ('MEAN') result_numeric=mean;
                when ('SD') result_numeric=std;
                when ('MEDIAN') result_numeric=median;
                when ('Q1') result_numeric=q1;
                when ('Q3') result_numeric=q3;
                when ('MIN') result_numeric=min;
                otherwise result_numeric=max;
            end;
            raw_value=strip(put(result_numeric,best32.));
            formatted_value=raw_value;
            result_key=catx('|',analysis_id,operation_id,operation_role,treatment);
            output;
        end;

        keep source_system reporting_event_id analysis_id method_id operation_id operation_role
             parameter_cd parameter treatment
             result_numeric result_char raw_value formatted_value display_id result_key;
    run;

    data _cnt_long_death;
        if _n_=1 then set _cnt_meta(obs=1);
        set _cnt_death2;
        length source_system $8 reporting_event_id $80 analysis_id $40 method_id $40 operation_id $40 operation_role $20
               parameter_cd $40 parameter $200 treatment $200 result_char $200 raw_value $64 formatted_value $200
               display_id $80 result_key $1000;
        length result_numeric 8;

        source_system='SAS';
        reporting_event_id="%superq(reporting_event_id)";
        analysis_id="&_analysis_id";
        method_id="%superq(method_id)";
        operation_id='OP_CNT_DEATH';
        display_id="%superq(display_id)";
        result_char='';

        do operation_role='COUNT','PCT';
            if operation_role='COUNT' then result_numeric=n;
            else result_numeric=pct;
            raw_value=strip(put(result_numeric,best32.));
            formatted_value=raw_value;
            result_key=catx('|',analysis_id,operation_id,operation_role,treatment);
            output;
        end;

        keep source_system reporting_event_id analysis_id method_id operation_id operation_role
             parameter_cd parameter treatment
             result_numeric result_char raw_value formatted_value display_id result_key;
    run;

    data _cnt_long_withdraw;
        if _n_=1 then set _cnt_meta(obs=1);
        set _cnt_withdraw2;
        length source_system $8 reporting_event_id $80 analysis_id $40 method_id $40 operation_id $40 operation_role $20
               parameter_cd $40 parameter $200 treatment $200 result_char $200 raw_value $64 formatted_value $200
               display_id $80 result_key $1000;
        length result_numeric 8;

        source_system='SAS';
        reporting_event_id="%superq(reporting_event_id)";
        analysis_id="&_analysis_id";
        method_id="%superq(method_id)";
        operation_id='OP_CNT_WITHDRAW';
        display_id="%superq(display_id)";
        result_char='';

        do operation_role='COUNT','PCT';
            if operation_role='COUNT' then result_numeric=n;
            else result_numeric=pct;
            raw_value=strip(put(result_numeric,best32.));
            formatted_value=raw_value;
            result_key=catx('|',analysis_id,operation_id,operation_role,treatment);
            output;
        end;

        keep source_system reporting_event_id analysis_id method_id operation_id operation_role
             parameter_cd parameter treatment
             result_numeric result_char raw_value formatted_value display_id result_key;
    run;

    data _cnt_long_cmp;
        if _n_=1 then set _cnt_meta(obs=1);
        set _cnt_cmp;
        length source_system $8 reporting_event_id $80 analysis_id $40 method_id $40 operation_id $40 operation_role $20
               parameter_cd $40 parameter $200 treatment $200 contrast $400 result_char $200 raw_value $64 formatted_value $200
               display_id $80 result_key $1000;
        length result_numeric 8;

        source_system='SAS';
        reporting_event_id="%superq(reporting_event_id)";
        analysis_id="&_analysis_id";
        method_id="%superq(method_id)";
        operation_id='OP_CNT_WMW';
        contrast=cats("%superq(test_value)",' vs ',"%superq(ref_value)");
        display_id="%superq(display_id)";
        result_char='';

        do operation_role='ESTIMATE','LCL','UCL','PVALUE';
            if operation_role='ESTIMATE' then result_numeric=est;
            else if operation_role='LCL' then result_numeric=lcl;
            else if operation_role='UCL' then result_numeric=ucl;
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
        set _cnt_long_stats _cnt_long_death _cnt_long_withdraw _cnt_long_cmp;
    run;

%mend ars_count_production_analysis;
