/****************************************************************************
* Program:      ars_tte_make_output.sas
* Macro:        %ars_tte_make_output
* Purpose:      Build report-ready COL0/COL1/COL2 rows for TTE summaries
*               from ARS-normalized Cox PH + Kaplan-Meier outputs.
****************************************************************************/

%macro ars_tte_make_output(
    arsds=,
    out=,
    test_value=,
    ref_value=,
    test_hdr=,
    ref_hdr=,
    day_label=28,
    display_id=,
    refno=,
    paramcd=,
    param=,
    where_clause=,
    strict_param=N,
    statfmt=8.2,
    sdfmt=8.1,
    pctfmt=8.1,
    hrfmt=8.3,
    pfmt=pvalue6.3,
    mockshell=N
);

    %local _mockshell _src_n _strict_param;
    %let _mockshell=%upcase(%superq(mockshell));
    %let _strict_param=%upcase(%superq(strict_param));

    %if %superq(arsds)= or not %sysfunc(exist(&arsds)) %then %do;
        %put ERROR: ars_tte_make_output - ARSDS is required and must exist.;
        %return;
    %end;

    %if %superq(out)= %then %do;
        %put ERROR: ars_tte_make_output - OUT is required.;
        %return;
    %end;

    data _tte_src;
        set &arsds;
        where 1=1
            %if %superq(display_id) ne %then and upcase(compbl(strip(display_id)))=upcase(compbl(strip("%superq(display_id)")));
            %if %superq(paramcd) ne %then and upcase(compbl(strip(parameter_cd)))=upcase(compbl(strip("%superq(paramcd)")));
            %if %superq(param) ne and (%superq(paramcd)= or &_strict_param=Y) %then and upcase(compbl(strip(parameter)))=upcase(compbl(strip("%superq(param)")));
            %if %superq(where_clause) ne %then and (&where_clause);
        ;
    run;

    proc sql noprint;
        select count(*) into :_src_n trimmed
        from _tte_src;
    quit;

    %if %superq(_src_n)=0 %then %do;
        %put WARNING: ars_tte_make_output - No rows after filtering. Check DISPLAY_ID/PARAMCD/PARAM filters or leave PARAM blank if label text differs.;
    %end;
    %else %if %superq(param) ne and %superq(paramcd) ne and &_strict_param ne Y %then %do;
        %put NOTE: ars_tte_make_output - PARAM filter ignored because PARAMCD is supplied and STRICT_PARAM=N.;
    %end;

    proc sql;
        create table _desc as
        select treatment,
               max(case when upcase(operation_role)='N' then result_numeric end) as n,
               max(case when upcase(operation_role)='MEAN' then result_numeric end) as mean,
               max(case when upcase(operation_role)='SD' then result_numeric end) as sd,
               max(case when upcase(operation_role)='MEDIAN' then result_numeric end) as median,
               max(case when upcase(operation_role)='MIN' then result_numeric end) as min,
               max(case when upcase(operation_role)='MAX' then result_numeric end) as max
        from _tte_src
        where upcase(operation_id)='OP_TTE_DESC'
        group by treatment;

        create table _cinc as
        select treatment,
               max(result_numeric) as cuminc
        from _tte_src
        where upcase(operation_id)='OP_TTE_KM_CINC'
          and upcase(operation_role)='PCT'
        group by treatment;

        create table _cens as
        select treatment,
               max(case when upcase(operation_role)='N_CENS' then result_numeric end) as n_cens,
               max(case when upcase(operation_role)='PCT_CENS' then result_numeric end) as pct_cens
        from _tte_src
        where upcase(operation_id)='OP_TTE_CENSOR'
        group by treatment;

        create table _med as
        select treatment,
               max(case when upcase(operation_role)='ESTIMATE' then result_numeric end) as med,
               max(case when upcase(operation_role)='LCL' then result_numeric end) as lcl,
               max(case when upcase(operation_role)='UCL' then result_numeric end) as ucl
        from _tte_src
        where upcase(operation_id)='OP_TTE_KM_MEDIAN'
        group by treatment;

        create table _hr as
        select max(case when upcase(operation_role)='ESTIMATE' then result_numeric end) as hr,
               max(case when upcase(operation_role)='LCL' then result_numeric end) as lcl,
               max(case when upcase(operation_role)='UCL' then result_numeric end) as ucl,
               max(case when upcase(operation_role)='PVALUE' then result_numeric end) as pval
        from _tte_src
        where upcase(operation_id)='OP_TTE_COX_HR';

        create table _test as
        select d.*, c.cuminc, z.n_cens, z.pct_cens, m.med, m.lcl, m.ucl
        from _desc d
        left join _cinc c on upcase(strip(d.treatment))=upcase(strip(c.treatment))
        left join _cens z on upcase(strip(d.treatment))=upcase(strip(z.treatment))
        left join _med m on upcase(strip(d.treatment))=upcase(strip(m.treatment))
        where upcase(strip(d.treatment))=upcase(strip("%superq(test_value)"));

        create table _ref as
        select d.*, c.cuminc, z.n_cens, z.pct_cens, m.med, m.lcl, m.ucl
        from _desc d
        left join _cinc c on upcase(strip(d.treatment))=upcase(strip(c.treatment))
        left join _cens z on upcase(strip(d.treatment))=upcase(strip(z.treatment))
        left join _med m on upcase(strip(d.treatment))=upcase(strip(m.treatment))
        where upcase(strip(d.treatment))=upcase(strip("%superq(ref_value)"));

        create table _one as
        select
            a.n as test_n,
            a.mean as test_mean,
            a.sd as test_sd,
            a.median as test_median,
            a.min as test_min,
            a.max as test_max,
            a.cuminc as test_cuminc,
            a.n_cens as test_n_cens,
            a.pct_cens as test_pct_cens,
            a.med as test_med,
            a.lcl as test_lcl,
            a.ucl as test_ucl,
            b.n as ref_n,
            b.mean as ref_mean,
            b.sd as ref_sd,
            b.median as ref_median,
            b.min as ref_min,
            b.max as ref_max,
            b.cuminc as ref_cuminc,
            b.n_cens as ref_n_cens,
            b.pct_cens as ref_pct_cens,
            b.med as ref_med,
            b.lcl as ref_lcl,
            b.ucl as ref_ucl,
            h.hr as hr_est,
            h.lcl as hr_lcl,
            h.ucl as hr_ucl,
            h.pval as hr_pval
        from _test as a
        full join _ref as b on 1=1
        full join _hr as h on 1=1;
    quit;

    data &out;
        set _one;
        length col0 col1 col2 $200;
        length _test_medc _test_lclc _test_uclc _ref_medc _ref_lclc _ref_uclc $32;
        length page order index 8;

        page=1; order=1; index=1; col0='Time to Event (Days)'; col1=''; col2=''; output;

        page=1; order=1; index=2; col0='n';
        if "&_mockshell"='Y' then do; col1='xx'; col2='xx'; end;
        else do; col1=strip(put(test_n,best12.)); col2=strip(put(ref_n,best12.)); end;
        output;

        page=1; order=1; index=3; col0='Mean (SD)';
        if "&_mockshell"='Y' then do; col1='xx (xx.x)'; col2='xx (xx.x)'; end;
        else do;
            col1=cats(strip(put(test_mean,&statfmt)),' (',strip(put(test_sd,&sdfmt)),')');
            col2=cats(strip(put(ref_mean,&statfmt)),' (',strip(put(ref_sd,&sdfmt)),')');
        end;
        output;

        page=1; order=1; index=4; col0='Median';
        if "&_mockshell"='Y' then do; col1='xx.xx'; col2='xx.xx'; end;
        else do; col1=strip(put(test_median,&statfmt)); col2=strip(put(ref_median,&statfmt)); end;
        output;

        page=1; order=1; index=5; col0='Min, Max';
        if "&_mockshell"='Y' then do; col1='xx, xx'; col2='xx, xx'; end;
        else do;
            col1=cats(strip(put(test_min,&statfmt)),', ',strip(put(test_max,&statfmt)));
            col2=cats(strip(put(ref_min,&statfmt)),', ',strip(put(ref_max,&statfmt)));
        end;
        output;

        page=1; order=2; index=1;
        col0=cats('Cumulative Incidence of Improvement by Day ',strip("&day_label"),' (%)');
        if "&_mockshell"='Y' then do; col1='xx (xx.x%)'; col2='xx (xx.x%)'; end;
        else do;
            col1=cats(strip(put(test_cuminc,&statfmt)),'%');
            col2=cats(strip(put(ref_cuminc,&statfmt)),'%');
        end;
        output;

        page=1; order=3; index=1; col0='Number of Censored Participants';
        if "&_mockshell"='Y' then do; col1='xx (xx.x%)'; col2='xx (xx.x%)'; end;
        else do;
            col1=cats(strip(put(test_n_cens,best12.)),' (',strip(put(test_pct_cens,&pctfmt)),'%)');
            col2=cats(strip(put(ref_n_cens,best12.)),' (',strip(put(ref_pct_cens,&pctfmt)),'%)');
        end;
        output;

        page=1; order=4; index=1; col0='Median Time to Improvement (Days) (95% CI)';
        if "&_mockshell"='Y' then do; col1='xx.xx (xx.xx, xx.xx)'; col2='xx.xx (xx.xx, xx.xx)'; end;
        else do;
            if missing(test_med) then _test_medc='NE';
            else _test_medc=strip(put(test_med,&statfmt));
            if missing(test_lcl) then _test_lclc='NE';
            else _test_lclc=strip(put(test_lcl,&statfmt));
            if missing(test_ucl) then _test_uclc='NE';
            else _test_uclc=strip(put(test_ucl,&statfmt));

            if missing(ref_med) then _ref_medc='NE';
            else _ref_medc=strip(put(ref_med,&statfmt));
            if missing(ref_lcl) then _ref_lclc='NE';
            else _ref_lclc=strip(put(ref_lcl,&statfmt));
            if missing(ref_ucl) then _ref_uclc='NE';
            else _ref_uclc=strip(put(ref_ucl,&statfmt));

            col1=cats(_test_medc,' (',_test_lclc,', ',_test_uclc,')');
            col2=cats(_ref_medc,' (',_ref_lclc,', ',_ref_uclc,')');
        end;
        output;

        page=1; order=5; index=1; col0=cats('Hazard Ratio (',"%superq(test_hdr)",' vs ' ,"%superq(ref_hdr)",')');
        if "&_mockshell"='Y' then col1='xx.xxx';
        else col1=strip(put(hr_est,&hrfmt));
        col2=''; output;

        page=1; order=5; index=2; col0='95% CI';
        if "&_mockshell"='Y' then col1='(xx.xx, xx.xx)';
        else col1=cats('(',strip(put(hr_lcl,&hrfmt)),', ',strip(put(hr_ucl,&hrfmt)),')');
        col2=''; output;

        page=1; order=5; index=3; col0='P-value';
        if "&_mockshell"='Y' then col1='x.xxx';
        else if not missing(hr_pval) and hr_pval < 0.001 then col1='<0.001';
        else col1=strip(put(hr_pval,&pfmt));
        col2=''; output;

        keep page order index col0 col1 col2;
    run;

    proc sort data=&out;
        by page order index;
    run;

    %if %superq(refno) ne %then %do;
        %if %sysfunc(libref(output)) = 0 %then %do;
            data output.&refno;
                set &out;
            run;
        %end;
        %else %do;
            %put WARNING: ars_tte_make_output - LIBREF OUTPUT is not assigned. Unable to create OUTPUT.&refno..;
        %end;
    %end;

    proc datasets lib=work nolist;
        delete _tte_src _desc _cinc _cens _med _hr _test _ref _one;
    quit;

%mend ars_tte_make_output;
