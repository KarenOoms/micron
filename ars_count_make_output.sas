/****************************************************************************
* Program:      ars_count_make_output.sas
* Macro:        %ars_count_make_output
* Purpose:      Build report-ready rows for count endpoint WMW/HL outputs.
****************************************************************************/

%macro ars_count_make_output(
    arsds=,
    out=,
    test_value=,
    ref_value=,
    endpoint_label=,
    day_label=28,
    death_label=Number of Participants that Died up to Day,
    withdraw_label=Number of Participants that Withdrew up to Day,
    test_hdr=,
    ref_hdr=,
    total_hdr=Total,
    include_total=Y,
    display_id=,
    refno=,
    paramcd=,
    param=,
    strict_param=N,
    nfmt=8.,
    statfmt=8.1,
    diff_fmt=8.2,
    pfmt=pvalue6.3,
    mockshell=N
);

    %local _mockshell _strict_param _src_n _include_total;
    %let _mockshell=%upcase(%superq(mockshell));
    %let _strict_param=%upcase(%superq(strict_param));
    %let _include_total=%upcase(%superq(include_total));

    %if &_include_total ne Y and &_include_total ne N %then %do;
        %put ERROR: ars_count_make_output - INCLUDE_TOTAL must be Y or N.;
        %return;
    %end;

    data _cnt_src;
        set &arsds;
        where 1=1
            %if %superq(display_id) ne %then and upcase(strip(display_id))=upcase(strip("%superq(display_id)"));
            %if %superq(paramcd) ne %then and upcase(strip(parameter_cd))=upcase(strip("%superq(paramcd)"));
            %if %superq(param) ne and (%superq(paramcd)= or &_strict_param=Y) %then and upcase(compbl(strip(parameter)))=upcase(compbl(strip("%superq(param)")));
        ;
    run;

    proc sql noprint;
        select count(*) into :_src_n trimmed from _cnt_src;
    quit;

    %if %superq(_src_n)=0 %then %do;
        %put WARNING: ars_count_make_output - No rows after filtering. Check DISPLAY_ID/PARAMCD/PARAM filters or leave PARAM blank if label text differs.;
    %end;

    proc sql;
        create table _desc as
        select treatment,
               max(case when upcase(operation_role)='N' then result_numeric end) as n,
               max(case when upcase(operation_role)='MEAN' then result_numeric end) as mean,
               max(case when upcase(operation_role)='SD' then result_numeric end) as sd,
               max(case when upcase(operation_role)='MEDIAN' then result_numeric end) as median,
               max(case when upcase(operation_role)='Q1' then result_numeric end) as q1,
               max(case when upcase(operation_role)='Q3' then result_numeric end) as q3,
               max(case when upcase(operation_role)='MIN' then result_numeric end) as min,
               max(case when upcase(operation_role)='MAX' then result_numeric end) as max
        from _cnt_src
        where upcase(operation_id)='OP_CNT_DESC'
        group by treatment;

        create table _death as
        select treatment,
               max(case when upcase(operation_role)='COUNT' then result_numeric end) as n,
               max(case when upcase(operation_role)='PCT' then result_numeric end) as pct
        from _cnt_src
        where upcase(operation_id)='OP_CNT_DEATH'
        group by treatment;

        create table _withdraw as
        select treatment,
               max(case when upcase(operation_role)='COUNT' then result_numeric end) as n,
               max(case when upcase(operation_role)='PCT' then result_numeric end) as pct
        from _cnt_src
        where upcase(operation_id)='OP_CNT_WITHDRAW'
        group by treatment;

        create table _cmp as
        select max(case when upcase(operation_role)='ESTIMATE' then result_numeric end) as est,
               max(case when upcase(operation_role)='LCL' then result_numeric end) as lcl,
               max(case when upcase(operation_role)='UCL' then result_numeric end) as ucl,
               max(case when upcase(operation_role)='PVALUE' then result_numeric end) as pval
        from _cnt_src
        where upcase(operation_id)='OP_CNT_WMW';
    quit;

    proc sql;
        create table _test as select * from _desc where upcase(strip(treatment))=upcase(strip("%superq(test_value)"));
        create table _ref as select * from _desc where upcase(strip(treatment))=upcase(strip("%superq(ref_value)"));
        create table _tot as select * from _desc where upcase(strip(treatment))='TOTAL';

        create table _dt as select * from _death where upcase(strip(treatment))=upcase(strip("%superq(test_value)"));
        create table _dr as select * from _death where upcase(strip(treatment))=upcase(strip("%superq(ref_value)"));
        create table _dall as select * from _death where upcase(strip(treatment))='TOTAL';

        create table _wt as select * from _withdraw where upcase(strip(treatment))=upcase(strip("%superq(test_value)"));
        create table _wr as select * from _withdraw where upcase(strip(treatment))=upcase(strip("%superq(ref_value)"));
        create table _wall as select * from _withdraw where upcase(strip(treatment))='TOTAL';

        create table _one as
        select t.n as t_n, t.mean as t_mean, t.sd as t_sd, t.median as t_median, t.q1 as t_q1, t.q3 as t_q3, t.min as t_min, t.max as t_max,
               r.n as r_n, r.mean as r_mean, r.sd as r_sd, r.median as r_median, r.q1 as r_q1, r.q3 as r_q3, r.min as r_min, r.max as r_max,
               a.n as a_n, a.mean as a_mean, a.sd as a_sd, a.median as a_median, a.q1 as a_q1, a.q3 as a_q3, a.min as a_min, a.max as a_max,
               dt.n as dt_n, dt.pct as dt_pct, dr.n as dr_n, dr.pct as dr_pct, da.n as da_n, da.pct as da_pct,
               wt.n as wt_n, wt.pct as wt_pct, wr.n as wr_n, wr.pct as wr_pct, wa.n as wa_n, wa.pct as wa_pct,
               c.est, c.lcl, c.ucl, c.pval
        from _test t full join _ref r on 1=1
             full join _tot a on 1=1
             full join _dt dt on 1=1
             full join _dr dr on 1=1
             full join _dall da on 1=1
             full join _wt wt on 1=1
             full join _wr wr on 1=1
             full join _wall wa on 1=1
             full join _cmp c on 1=1;
    quit;

    data &out;
        set _one;
        length col0 col1 col2 col3 $200;
        length page order index 8;

        page=1; order=1; index=1; col0=cat('Number of ',strip("%superq(endpoint_label)"),' (Days)'); col1=''; col2=''; col3=''; output;
        page=1; order=1; index=2; col0='n';
        if "&_mockshell"='Y' then do; col1='xx'; col2='xx'; if "&_include_total"='Y' then col3='xx'; else col3=''; end;
        else do;
            col1=strip(put(coalesce(t_n,0),&nfmt));
            col2=strip(put(coalesce(r_n,0),&nfmt));
            if "&_include_total"='Y' then col3=strip(put(coalesce(a_n,0),&nfmt));
            else col3='';
        end;
        output;

        page=1; order=1; index=3; col0='Mean (SD)';
        if "&_mockshell"='Y' then do; col1='xx (xx)'; col2='xx (xx)'; if "&_include_total"='Y' then col3='xx (xx)'; else col3=''; end;
        else do;
            col1=cat(strip(put(coalesce(t_mean,0),&statfmt)),' (',strip(put(coalesce(t_sd,0),&statfmt)),')');
            col2=cat(strip(put(coalesce(r_mean,0),&statfmt)),' (',strip(put(coalesce(r_sd,0),&statfmt)),')');
            if "&_include_total"='Y' then col3=cat(strip(put(coalesce(a_mean,0),&statfmt)),' (',strip(put(coalesce(a_sd,0),&statfmt)),')');
            else col3='';
        end;
        output;

        page=1; order=1; index=4; col0='Median';
        if "&_mockshell"='Y' then do; col1='xx.x'; col2='xx.x'; if "&_include_total"='Y' then col3='xx.x'; else col3=''; end;
        else do;
            col1=strip(put(coalesce(t_median,0),&statfmt));
            col2=strip(put(coalesce(r_median,0),&statfmt));
            if "&_include_total"='Y' then col3=strip(put(coalesce(a_median,0),&statfmt));
            else col3='';
        end;
        output;

        page=1; order=1; index=5; col0='Q1, Q3';
        if "&_mockshell"='Y' then do; col1='xx.x, xx.x'; col2='xx.x, xx.x'; if "&_include_total"='Y' then col3='xx.x, xx.x'; else col3=''; end;
        else do;
            col1=cat(strip(put(coalesce(t_q1,0),&statfmt)),', ',strip(put(coalesce(t_q3,0),&statfmt)));
            col2=cat(strip(put(coalesce(r_q1,0),&statfmt)),', ',strip(put(coalesce(r_q3,0),&statfmt)));
            if "&_include_total"='Y' then col3=cat(strip(put(coalesce(a_q1,0),&statfmt)),', ',strip(put(coalesce(a_q3,0),&statfmt)));
            else col3='';
        end;
        output;

        page=1; order=1; index=6; col0='Min, Max';
        if "&_mockshell"='Y' then do; col1='xx, xx'; col2='xx, xx'; if "&_include_total"='Y' then col3='xx, xx'; else col3=''; end;
        else do;
            col1=cat(strip(put(coalesce(t_min,0),&statfmt)),', ',strip(put(coalesce(t_max,0),&statfmt)));
            col2=cat(strip(put(coalesce(r_min,0),&statfmt)),', ',strip(put(coalesce(r_max,0),&statfmt)));
            if "&_include_total"='Y' then col3=cat(strip(put(coalesce(a_min,0),&statfmt)),', ',strip(put(coalesce(a_max,0),&statfmt)));
            else col3='';
        end;
        output;

        page=1; order=2; index=1; col0=catx(' ',"%superq(death_label)",strip("&day_label"));
        if "&_mockshell"='Y' then do; col1='xx (xx.x%)'; col2='xx (xx.x%)'; if "&_include_total"='Y' then col3='xx (xx.x%)'; else col3=''; end;
        else do;
            col1=cat(strip(put(coalesce(dt_n,0),&nfmt)),' (',strip(put(coalesce(dt_pct,0),&statfmt)),'%)');
            col2=cat(strip(put(coalesce(dr_n,0),&nfmt)),' (',strip(put(coalesce(dr_pct,0),&statfmt)),'%)');
            if "&_include_total"='Y' then col3=cat(strip(put(coalesce(da_n,0),&nfmt)),' (',strip(put(coalesce(da_pct,0),&statfmt)),'%)');
            else col3='';
        end;
        output;

        page=1; order=3; index=1; col0=catx(' ',"%superq(withdraw_label)",strip("&day_label"));
        if "&_mockshell"='Y' then do; col1='xx (xx.x%)'; col2='xx (xx.x%)'; if "&_include_total"='Y' then col3='xx (xx.x%)'; else col3=''; end;
        else do;
            col1=cat(strip(put(coalesce(wt_n,0),&nfmt)),' (',strip(put(coalesce(wt_pct,0),&statfmt)),'%)');
            col2=cat(strip(put(coalesce(wr_n,0),&nfmt)),' (',strip(put(coalesce(wr_pct,0),&statfmt)),'%)');
            if "&_include_total"='Y' then col3=cat(strip(put(coalesce(wa_n,0),&nfmt)),' (',strip(put(coalesce(wa_pct,0),&statfmt)),'%)');
            else col3='';
        end;
        output;

        page=1; order=4; index=1; col0='Hodges-Lehmann median difference'; col1=''; col2=''; col3=''; output;
        page=1; order=4; index=2; col0=cat('(',strip("%superq(test_hdr)"),' vs ',strip("%superq(ref_hdr)"),')');
        if "&_mockshell"='Y' then col1='x.xx';
        else col1=strip(put(est,&diff_fmt));
        col2=''; col3=''; output;

        page=1; order=4; index=3; col0='95% CI';
        if "&_mockshell"='Y' then col1='(xx.xx, xx.xx)';
        else col1=cat('(',strip(put(lcl,&diff_fmt)),', ',strip(put(ucl,&diff_fmt)),')');
        col2=''; col3=''; output;

        page=1; order=4; index=4; col0='P-Value';
        if "&_mockshell"='Y' then col1='x.xxx';
        else if missing(pval) then col1='';
        else if pval<0.001 then col1='<0.001';
        else col1=strip(put(pval,&pfmt));
        col2=''; col3=''; output;

        keep page order index col0 col1 col2
            %if &_include_total=Y %then %do; col3 %end;
        ;
    run;

    %if %superq(refno) ne %then %do;
        %if %sysfunc(libref(output)) = 0 %then %do;
            data output.&refno;
                set &out;
            run;
        %end;
        %else %do;
            %put WARNING: ars_count_make_output - LIBREF OUTPUT is not assigned. Unable to create OUTPUT.&refno..;
        %end;
    %end;

%mend ars_count_make_output;
