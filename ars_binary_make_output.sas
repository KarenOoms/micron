/****************************************************************************
* Program:      ars_binary_make_output.sas
* Macro:        %ars_binary_make_output
* Purpose:      Build report-ready rows for binary Fisher endpoints.
****************************************************************************/

%macro ars_binary_make_output(
    arsds=,
    out=,
    test_value=,
    ref_value=,
    test_hdr=,
    ref_hdr=,
    day_label=28,
    event_label=Received Newly Initiated RRT,
    non_event_label=Did not Receive Newly Initiated RRT,
    missing_label=Missing,
    display_id=,
    refno=,
    paramcd=,
    param=,
    strict_param=N,
    where_clause=,
    countfmt=8.,
    pctfmt=8.1,
    orfmt=8.3,
    pfmt=pvalue6.3,
    mockshell=N
);

    %local _mockshell _strict_param _src_n;
    %let _mockshell=%upcase(%superq(mockshell));
    %let _strict_param=%upcase(%superq(strict_param));

    data _bin_src;
        set &arsds;
        where 1=1
            %if %superq(display_id) ne %then and upcase(strip(display_id))=upcase(strip("%superq(display_id)"));
            %if %superq(paramcd) ne %then and upcase(strip(parameter_cd))=upcase(strip("%superq(paramcd)"));
            %if %superq(param) ne and (%superq(paramcd)= or &_strict_param=Y) %then and upcase(compbl(strip(parameter)))=upcase(compbl(strip("%superq(param)")));
            %if %superq(where_clause) ne %then and (&where_clause);
        ;
    run;

    proc sql noprint;
        select count(*) into :_src_n trimmed
        from _bin_src;
    quit;

    %if %superq(_src_n)=0 %then %do;
        %put WARNING: ars_binary_make_output - No rows after filtering. Check DISPLAY_ID/PARAMCD/PARAM filters or leave PARAM blank if label text differs.;
    %end;
    %else %if %superq(param) ne and %superq(paramcd) ne and &_strict_param ne Y %then %do;
        %put NOTE: ars_binary_make_output - PARAM filter ignored because PARAMCD is supplied and STRICT_PARAM=N.;
    %end;

    proc sql;
        create table _cnt as
        select treatment, grouping_1_value,
               max(case when upcase(operation_role)='COUNT' then result_numeric end) as n,
               max(case when upcase(operation_role)='PCT' then result_numeric end) as pct
        from _bin_src
        where upcase(operation_id)='OP_BIN_COUNT_PCT'
        group by treatment, grouping_1_value;

        create table _or as
        select max(case when upcase(operation_role)='ESTIMATE' then result_numeric end) as or_est,
               max(case when upcase(operation_role)='LCL' then result_numeric end) as or_lcl,
               max(case when upcase(operation_role)='UCL' then result_numeric end) as or_ucl,
               max(case when upcase(operation_role)='PVALUE' then result_numeric end) as pval
        from _bin_src
        where upcase(operation_id)='OP_BIN_OR';
    quit;

    proc sql;
        create table _test as
        select max(case when grouping_1_value='EVENT' then n end) as e_n,
               max(case when grouping_1_value='EVENT' then pct end) as e_pct,
               max(case when grouping_1_value='NON_EVENT' then n end) as ne_n,
               max(case when grouping_1_value='NON_EVENT' then pct end) as ne_pct,
               max(case when grouping_1_value='MISSING' then n end) as m_n,
               max(case when grouping_1_value='MISSING' then pct end) as m_pct
        from _cnt
        where upcase(strip(treatment))=upcase(strip("%superq(test_value)"));

        create table _ref as
        select max(case when grouping_1_value='EVENT' then n end) as e_n,
               max(case when grouping_1_value='EVENT' then pct end) as e_pct,
               max(case when grouping_1_value='NON_EVENT' then n end) as ne_n,
               max(case when grouping_1_value='NON_EVENT' then pct end) as ne_pct,
               max(case when grouping_1_value='MISSING' then n end) as m_n,
               max(case when grouping_1_value='MISSING' then pct end) as m_pct
        from _cnt
        where upcase(strip(treatment))=upcase(strip("%superq(ref_value)"));

        create table _one as
        select t.e_n as test_e_n, t.e_pct as test_e_pct,
               t.ne_n as test_ne_n, t.ne_pct as test_ne_pct,
               t.m_n as test_m_n, t.m_pct as test_m_pct,
               r.e_n as ref_e_n, r.e_pct as ref_e_pct,
               r.ne_n as ref_ne_n, r.ne_pct as ref_ne_pct,
               r.m_n as ref_m_n, r.m_pct as ref_m_pct,
               o.or_est, o.or_lcl, o.or_ucl, o.pval
        from _test t full join _ref r on 1=1 full join _or o on 1=1;
    quit;

    data &out;
        set _one;
        length col0 col1 col2 $200;
        length page order index 8;

        page=1; order=1; index=1;
        col0=catx(' ','Number of Participants up to and including Day',strip("&day_label"));
        col1=''; col2=''; output;

        page=1; order=1; index=2; col0="&event_label";
        if "&_mockshell"='Y' then do; col1='xx (xx.x%)'; col2='xx (xx.x%)'; end;
        else do;
            col1=cat(strip(put(coalesce(test_e_n,0),&countfmt)),' (',strip(put(coalesce(test_e_pct,0),&pctfmt)),'%)');
            col2=cat(strip(put(coalesce(ref_e_n,0),&countfmt)),' (',strip(put(coalesce(ref_e_pct,0),&pctfmt)),'%)');
        end;
        output;

        page=1; order=1; index=3; col0="&non_event_label";
        if "&_mockshell"='Y' then do; col1='xx (xx.x%)'; col2='xx (xx.x%)'; end;
        else do;
            col1=cat(strip(put(coalesce(test_ne_n,0),&countfmt)),' (',strip(put(coalesce(test_ne_pct,0),&pctfmt)),'%)');
            col2=cat(strip(put(coalesce(ref_ne_n,0),&countfmt)),' (',strip(put(coalesce(ref_ne_pct,0),&pctfmt)),'%)');
        end;
        output;

        page=1; order=1; index=4; col0="&missing_label";
        if "&_mockshell"='Y' then do;
            col1='xx (xx.x%)'; col2='xx (xx.x%)';
            output;
        end;
        else if max(coalesce(test_m_n,0),coalesce(ref_m_n,0),
                    coalesce(test_m_pct,0),coalesce(ref_m_pct,0))>0 then do;
            col1=cat(strip(put(coalesce(test_m_n,0),&countfmt)),' (',strip(put(coalesce(test_m_pct,0),&pctfmt)),'%)');
            col2=cat(strip(put(coalesce(ref_m_n,0),&countfmt)),' (',strip(put(coalesce(ref_m_pct,0),&pctfmt)),'%)');
            output;
        end;

        page=1; order=2; index=1;
        col0=cat('Odds Ratio (',strip("%superq(test_hdr)"),' vs ',strip("%superq(ref_hdr)"),')');
        if "&_mockshell"='Y' then col1='x.xx';
        else col1=strip(put(or_est,&orfmt));
        col2=''; output;

        page=1; order=2; index=2; col0='95% CI';
        if "&_mockshell"='Y' then col1='(xx.xx, xx.xx)';
        else col1=cat('(',strip(put(or_lcl,&orfmt)),', ',strip(put(or_ucl,&orfmt)),')');
        col2=''; output;

        page=1; order=2; index=3; col0='p-value';
        if "&_mockshell"='Y' then col1='x.xxx';
        else if pval<0.001 then col1='<0.001';
        else col1=strip(put(pval,&pfmt));
        col2=''; output;

        keep page order index col0 col1 col2;
    run;

    %if %superq(refno) ne %then %do;
        %if %sysfunc(libref(output)) = 0 %then %do;
            data output.&refno;
                set &out;
            run;
        %end;
        %else %do;
            %put WARNING: ars_binary_make_output - LIBREF OUTPUT is not assigned. Unable to create OUTPUT.&refno..;
        %end;
    %end;

%mend ars_binary_make_output;
