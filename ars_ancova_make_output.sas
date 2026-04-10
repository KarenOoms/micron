/****************************************************************************
* Program:      ars_ancova_make_output.sas
* Macro:        %ars_ancova_make_output
* Purpose:      Build report-ready page dataset for ANCOVA adjusted estimates
*               from canonical ARS-like long results data.
****************************************************************************/

%macro ars_ancova_make_output(
    arsds=,
    out=,
    test_value=,
    ref_value=,
    test_hdr=,
    ref_hdr=,
    n_test=,
    n_ref=,
    n_total=,
    pop_dsin=,
    pop_byvar=,
    pop_subject=USUBJID,
    pop_maxcols=2,
    pop_test_col=1,
    pop_ref_col=2,
    paramcd=,
    param=,
    strict_param=N,
    avisit=,
    avisitn=,
    display_id=,
    refno=,
    meanfmt=8.2,
    sefmt=8.1,
    pfmt=pvalue6.3,
    mockshell=N,
    total_label=Total,
    where_clause=
    ,include_desc_stats=Y
    ,desc_dsin=
    ,desc_where=
    ,desc_trt_var=
    ,desc_base_var=BASE
    ,desc_aval_var=AVAL
    ,desc_chg_var=CHG
    ,desc_base_label=S/F Ratio at Baseline
    ,desc_aval_label=S/F Ratio at Day 7
    ,desc_chg_label=Change from Baseline to Day 7
    ,desc_nfmt=8.
    ,desc_statfmt=8.1
);

    %local _mockshell _strict_param _n_test _n_ref _n_total _totvar_test _totvar_ref _totvar_all
           _dsid _rc _has_display_id _has_parameter_cd _has_parameter _has_avisit _has_avisitn
           _has_avisit_nonmiss _has_avisitn_nonmiss;
    %let _mockshell=%upcase(%superq(mockshell));
    %let _strict_param=%upcase(%superq(strict_param));
    %let _n_test=%superq(n_test);
    %let _n_ref=%superq(n_ref);
    %let _n_total=%superq(n_total);

    %if %superq(arsds)= or not %sysfunc(exist(&arsds)) %then %do;
        %put ERROR: ars_make_ancova_page2 - ARSDS is required and must exist.;
        %return;
    %end;

    %if %superq(out)= %then %do;
        %put ERROR: ars_make_ancova_page2 - OUT dataset is required.;
        %return;
    %end;

    %if &_mockshell ne Y and &_mockshell ne N %then %do;
        %put ERROR: ars_make_ancova_page2 - MOCKSHELL must be Y or N.;
        %return;
    %end;
    %put NOTE: ars_make_ancova_page2 version 2026-04-09e (robust filter fallback enabled).;

    %let _has_display_id=0;
    %let _has_parameter_cd=0;
    %let _has_parameter=0;
    %let _has_avisit=0;
    %let _has_avisitn=0;
    %let _has_avisit_nonmiss=0;
    %let _has_avisitn_nonmiss=0;
    %let _dsid=%sysfunc(open(&arsds,i));
    %if &_dsid %then %do;
        %if %sysfunc(varnum(&_dsid,display_id)) > 0 %then %let _has_display_id=1;
        %if %sysfunc(varnum(&_dsid,parameter_cd)) > 0 %then %let _has_parameter_cd=1;
        %if %sysfunc(varnum(&_dsid,parameter)) > 0 %then %let _has_parameter=1;
        %if %sysfunc(varnum(&_dsid,avisit)) > 0 %then %let _has_avisit=1;
        %if %sysfunc(varnum(&_dsid,avisitn)) > 0 %then %let _has_avisitn=1;
        %let _rc=%sysfunc(close(&_dsid));
    %end;

    %if &_has_avisit %then %do;
        proc sql noprint;
            select count(*) into :_has_avisit_nonmiss trimmed
            from &arsds
            where not missing(avisit);
        quit;
    %end;
    %if &_has_avisitn %then %do;
        proc sql noprint;
            select count(*) into :_has_avisitn_nonmiss trimmed
            from &arsds
            where not missing(avisitn);
        quit;
    %end;

    /* Optional denominator derivation via popcount macro */
    %if (%superq(_n_test)= or %superq(_n_ref)= or %superq(_n_total)=)
        and %superq(pop_dsin) ne
        and %superq(pop_byvar) ne %then %do;

        %popcount5(
            dsin=&pop_dsin,
            byvar=&pop_byvar,
            subject=&pop_subject,
            maxcols=&pop_maxcols
        );

        %let _totvar_test=tot&pop_test_col;
        %let _totvar_ref=tot&pop_ref_col;
        %let _totvar_all=tot%eval(&pop_maxcols+1);

        %if %superq(_n_test)= %then %let _n_test=&&&_totvar_test;
        %if %superq(_n_ref)= %then %let _n_ref=&&&_totvar_ref;
        %if %superq(_n_total)= %then %let _n_total=&&&_totvar_all;
    %end;

    data _anc_src;
        set &arsds;
        where 1=1
            %if %length(%superq(display_id))>0 and &_has_display_id %then and strip(display_id)=strip("%superq(display_id)");
            %if %length(%superq(paramcd))>0 and &_has_parameter_cd %then and strip(parameter_cd)=strip("%superq(paramcd)");
            %if %length(%superq(param))>0 and &_has_parameter and (%length(%superq(paramcd))=0 or &_strict_param=Y) %then and strip(parameter)=strip("%superq(param)");
            %if %length(%superq(avisit))>0 and &_has_avisit and %sysevalf(&_has_avisit_nonmiss>0) %then and strip(avisit)=strip("%superq(avisit)");
            %if %length(%superq(avisitn))>0 and &_has_avisitn and %sysevalf(&_has_avisitn_nonmiss>0) %then and avisitn=%superq(avisitn);
            %if %superq(where_clause) ne %then and (&where_clause);
        ;
    run;

    %local _anc_n;
    proc sql noprint;
        select count(*) into :_anc_n trimmed from _anc_src;
    quit;

    %if %superq(_anc_n)=0 %then %do;
        %put NOTE: ars_make_ancova_page2 - No rows after initial filtering. Retrying without AVISIT/AVISITN filters.;
        data _anc_src;
            set &arsds;
            where 1=1
                %if %length(%superq(display_id))>0 and &_has_display_id %then and strip(display_id)=strip("%superq(display_id)");
                %if %length(%superq(paramcd))>0 and &_has_parameter_cd %then and strip(parameter_cd)=strip("%superq(paramcd)");
                %if %length(%superq(param))>0 and &_has_parameter and (%length(%superq(paramcd))=0 or &_strict_param=Y) %then and strip(parameter)=strip("%superq(param)");
                %if %superq(where_clause) ne %then and (&where_clause);
            ;
        run;
    %end;

    proc sql noprint;
        select count(*) into :_anc_n trimmed from _anc_src;
    quit;

    %if %superq(_anc_n)=0 and %length(%superq(param))>0 and %length(%superq(paramcd))>0 %then %do;
        %put NOTE: ars_make_ancova_page2 - Still no rows. Retrying without PARAM text filter.;
        data _anc_src;
            set &arsds;
            where 1=1
                %if %length(%superq(display_id))>0 and &_has_display_id %then and strip(display_id)=strip("%superq(display_id)");
                %if %length(%superq(paramcd))>0 and &_has_parameter_cd %then and strip(parameter_cd)=strip("%superq(paramcd)");
                %if %superq(where_clause) ne %then and (&where_clause);
            ;
        run;
    %end;

    proc sql noprint;
        select count(*) into :_anc_n trimmed from _anc_src;
    quit;

    %if %superq(_anc_n)=0 and %length(%superq(paramcd))>0 and &_has_parameter_cd %then %do;
        %put NOTE: ars_make_ancova_page2 - Still no rows. Retrying without PARAMCD filter.;
        data _anc_src;
            set &arsds;
            where 1=1
                %if %length(%superq(display_id))>0 and &_has_display_id %then and strip(display_id)=strip("%superq(display_id)");
                %if %superq(where_clause) ne %then and (&where_clause);
            ;
        run;
    %end;

    proc sql noprint;
        select count(*) into :_anc_n trimmed from _anc_src;
    quit;

    %if %superq(_anc_n)=0 and %length(%superq(display_id))>0 and &_has_display_id %then %do;
        %put NOTE: ars_make_ancova_page2 - Still no rows. Retrying without DISPLAY_ID filter.;
        data _anc_src;
            set &arsds;
            where 1=1
                %if %superq(where_clause) ne %then and (&where_clause);
            ;
        run;
    %end;

    %if %length(%superq(display_id))>0 and not &_has_display_id %then
        %put NOTE: ars_make_ancova_page2 - DISPLAY_ID filter ignored because DISPLAY_ID is not present in &arsds..;
    %if %length(%superq(paramcd))>0 and not &_has_parameter_cd %then
        %put NOTE: ars_make_ancova_page2 - PARAMCD filter ignored because PARAMETER_CD is not present in &arsds..;
    %if %length(%superq(param))>0 and not &_has_parameter %then
        %put NOTE: ars_make_ancova_page2 - PARAM filter ignored because PARAMETER is not present in &arsds..;
    %else %if %length(%superq(param))>0 and %length(%superq(paramcd))>0 and &_strict_param ne Y %then
        %put NOTE: ars_make_ancova_page2 - PARAM filter ignored because PARAMCD is supplied and STRICT_PARAM=N.;
    %if %length(%superq(avisit))>0 and not &_has_avisit %then
        %put NOTE: ars_make_ancova_page2 - AVISIT filter ignored because AVISIT is not present in &arsds..;
    %else %if %length(%superq(avisit))>0 and &_has_avisit and not %sysevalf(&_has_avisit_nonmiss>0) %then
        %put NOTE: ars_make_ancova_page2 - AVISIT filter ignored because AVISIT has only missing values in &arsds..;
    %if %length(%superq(avisitn))>0 and not &_has_avisitn %then
        %put NOTE: ars_make_ancova_page2 - AVISITN filter ignored because AVISITN is not present in &arsds..;
    %else %if %length(%superq(avisitn))>0 and &_has_avisitn and not %sysevalf(&_has_avisitn_nonmiss>0) %then
        %put NOTE: ars_make_ancova_page2 - AVISITN filter ignored because AVISITN has only missing values in &arsds..;

    proc sort data=_anc_src out=_anc_src_s;
        by descending result_sequence;
    run;

    /* treatment-level adjusted estimates */
    proc sql;
        create table _anc_lsm as
        select treatment,
               upcase(strip(operation_role)) as operation_role length=20,
               result_numeric
        from _anc_src_s
        where not missing(treatment)
          and missing(contrast)
          and upcase(strip(operation_role)) in ('LSMEAN','SE','LCL','UCL');
    quit;

    proc sort data=_anc_lsm nodupkey;
        by treatment operation_role;
    run;

    proc sql noprint;
        create table _anc_test as
        select
            max(case when operation_role='LSMEAN' then result_numeric end) as test_lsm,
            max(case when operation_role='SE' then result_numeric end) as test_se,
            max(case when operation_role='LCL' then result_numeric end) as test_lcl,
            max(case when operation_role='UCL' then result_numeric end) as test_ucl
        from _anc_lsm
          where upcase(strip(treatment))=upcase(strip("%superq(test_value)"));

        create table _anc_ref as
        select
            max(case when operation_role='LSMEAN' then result_numeric end) as ref_lsm,
            max(case when operation_role='SE' then result_numeric end) as ref_se,
            max(case when operation_role='LCL' then result_numeric end) as ref_lcl,
            max(case when operation_role='UCL' then result_numeric end) as ref_ucl
        from _anc_lsm
        where upcase(strip(treatment))=upcase(strip("%superq(ref_value)"));
    quit;

    /* active - placebo contrast, with automatic inversion when only reverse is present */
    data _anc_diff_pool;
        set _anc_src_s;
        where not missing(contrast)
          and upcase(strip(operation_role)) in ('ESTIMATE','SE','LCL','UCL','PVALUE');

        length _lhs _rhs $400 _contrast_norm $800;
        _contrast_norm=tranwrd(strip(contrast),' - ','|');
        _lhs=strip(scan(_contrast_norm,1,'|'));
        _rhs=strip(scan(_contrast_norm,2,'|'));

         if upcase(_lhs)=upcase(strip("%superq(test_value)")) and upcase(_rhs)=upcase(strip("%superq(ref_value)")) then _direction=1;
        else if upcase(_lhs)=upcase(strip("%superq(ref_value)")) and upcase(_rhs)=upcase(strip("%superq(test_value)")) then _direction=-1;
        else delete;
    run;

    proc sort data=_anc_diff_pool nodupkey;
        by operation_role;
    run;

    proc sql;
        create table _anc_diff as
        select
            max(case when upcase(operation_role)='ESTIMATE' then result_numeric end) as est_raw,
            max(case when upcase(operation_role)='SE' then result_numeric end) as se_raw,
            max(case when upcase(operation_role)='LCL' then result_numeric end) as lcl_raw,
            max(case when upcase(operation_role)='UCL' then result_numeric end) as ucl_raw,
            max(case when upcase(operation_role)='PVALUE' then result_numeric end) as pval_raw,
            max(_direction) as direction
        from _anc_diff_pool;
    quit;

    proc sql;
        create table _anc_one as
        select
            t.test_lsm, t.test_se, t.test_lcl, t.test_ucl,
            r.ref_lsm, r.ref_se, r.ref_lcl, r.ref_ucl,
            d.est_raw, d.se_raw, d.lcl_raw, d.ucl_raw, d.pval_raw, d.direction
        from _anc_test as t
        full join _anc_ref as r on 1=1
        full join _anc_diff as d on 1=1;
    quit;

    data _anc_one;
        set _anc_one;

        if missing(direction) then direction=1;

        diff_est=est_raw;
        diff_se=se_raw;
        diff_lcl=lcl_raw;
        diff_ucl=ucl_raw;
        diff_pval=pval_raw;

        if direction=-1 then do;
            diff_est=-est_raw;
            diff_lcl=-ucl_raw;
            diff_ucl=-lcl_raw;
        end;
    run;

    %if %upcase(%superq(include_desc_stats))=Y %then %do;
        %local _desc_src _desc_trt;
        %if %length(%superq(desc_dsin))>0 %then %let _desc_src=&desc_dsin;
        %else %if %length(%superq(pop_dsin))>0 %then %let _desc_src=&pop_dsin;
        %else %let _desc_src=;

        %if %length(%superq(desc_trt_var))>0 %then %let _desc_trt=&desc_trt_var;
        %else %let _desc_trt=&pop_byvar;

        %local _desc_mem;
        %let _desc_mem=%scan(%superq(_desc_src),1,%str(%());

        %if %length(%superq(_desc_src))>0 and %length(%superq(_desc_mem))>0 and %sysfunc(exist(&_desc_mem)) %then %do;
            data _anc_desc_in;
                set &_desc_src
                    %if %length(%superq(desc_where))>0 %then (where=(&desc_where));
                ;
                length treatment $200;
                treatment=vvalue(&_desc_trt);
                _base=&desc_base_var;
                _aval=&desc_aval_var;
                _chg=&desc_chg_var;
                keep treatment _base _aval _chg;
            run;

            proc summary data=_anc_desc_in;
                class treatment;
                var _base _aval _chg;
                output out=_anc_desc_stats(drop=_type_ _freq_)
                    n(_base)=base_n n(_aval)=aval_n n(_chg)=chg_n
                    mean(_base)=base_mean mean(_aval)=aval_mean mean(_chg)=chg_mean
                    std(_base)=base_sd std(_aval)=aval_sd std(_chg)=chg_sd
                    median(_base)=base_median median(_aval)=aval_median median(_chg)=chg_median
                    min(_base)=base_min min(_aval)=aval_min min(_chg)=chg_min
                    max(_base)=base_max max(_aval)=aval_max max(_chg)=chg_max;
            run;

            data _anc_desc_stats;
                set _anc_desc_stats;
                if missing(treatment) then treatment="&total_label";
            run;

            proc sql;
                create table _anc_desc_test as select * from _anc_desc_stats where upcase(strip(treatment))=upcase(strip("%superq(test_value)"));
                create table _anc_desc_ref as select * from _anc_desc_stats where upcase(strip(treatment))=upcase(strip("%superq(ref_value)"));
                create table _anc_desc_tot as select * from _anc_desc_stats where upcase(strip(treatment))=upcase(strip("&total_label"));
                create table _anc_desc_one as
                select
                    t.base_n as t_base_n, t.base_mean as t_base_mean, t.base_sd as t_base_sd, t.base_median as t_base_median, t.base_min as t_base_min, t.base_max as t_base_max,
                    t.aval_n as t_aval_n, t.aval_mean as t_aval_mean, t.aval_sd as t_aval_sd, t.aval_median as t_aval_median, t.aval_min as t_aval_min, t.aval_max as t_aval_max,
                    t.chg_n as t_chg_n, t.chg_mean as t_chg_mean, t.chg_sd as t_chg_sd, t.chg_median as t_chg_median, t.chg_min as t_chg_min, t.chg_max as t_chg_max,
                    r.base_n as r_base_n, r.base_mean as r_base_mean, r.base_sd as r_base_sd, r.base_median as r_base_median, r.base_min as r_base_min, r.base_max as r_base_max,
                    r.aval_n as r_aval_n, r.aval_mean as r_aval_mean, r.aval_sd as r_aval_sd, r.aval_median as r_aval_median, r.aval_min as r_aval_min, r.aval_max as r_aval_max,
                    r.chg_n as r_chg_n, r.chg_mean as r_chg_mean, r.chg_sd as r_chg_sd, r.chg_median as r_chg_median, r.chg_min as r_chg_min, r.chg_max as r_chg_max,
                    a.base_n as a_base_n, a.base_mean as a_base_mean, a.base_sd as a_base_sd, a.base_median as a_base_median, a.base_min as a_base_min, a.base_max as a_base_max,
                    a.aval_n as a_aval_n, a.aval_mean as a_aval_mean, a.aval_sd as a_aval_sd, a.aval_median as a_aval_median, a.aval_min as a_aval_min, a.aval_max as a_aval_max,
                    a.chg_n as a_chg_n, a.chg_mean as a_chg_mean, a.chg_sd as a_chg_sd, a.chg_median as a_chg_median, a.chg_min as a_chg_min, a.chg_max as a_chg_max
                from _anc_desc_test t full join _anc_desc_ref r on 1=1 full join _anc_desc_tot a on 1=1;

                create table _anc_final as
                select x.*, y.*
                from _anc_one x full join _anc_desc_one y on 1=1;
            quit;
        %end;
        %else %do;
            data _anc_final;
                set _anc_one;
            run;
        %end;
    %end;
    %else %do;
        data _anc_final;
            set _anc_one;
        run;
    %end;

    data &out;
        set _anc_final;
        length col0 col1 col2 col3 $200;
        length page order index 8;

        %if %upcase(%superq(include_desc_stats))=Y %then %do;
            page=1; order=1; index=1; col0="%superq(desc_base_label)"; col1=''; col2=''; col3=''; output;
            page=1; order=1; index=2; col0='   n';
            col1=strip(put(coalesce(r_base_n,0),&desc_nfmt)); col2=strip(put(coalesce(t_base_n,0),&desc_nfmt)); col3=strip(put(coalesce(a_base_n,0),&desc_nfmt)); output;
            page=1; order=1; index=3; col0='   Mean (SD)';
            col1=cats(strip(put(coalesce(r_base_mean,0),&desc_statfmt)),' (',strip(put(coalesce(r_base_sd,0),&desc_statfmt)),')');
            col2=cats(strip(put(coalesce(t_base_mean,0),&desc_statfmt)),' (',strip(put(coalesce(t_base_sd,0),&desc_statfmt)),')');
            col3=cats(strip(put(coalesce(a_base_mean,0),&desc_statfmt)),' (',strip(put(coalesce(a_base_sd,0),&desc_statfmt)),')'); output;
            page=1; order=1; index=4; col0='   Median';
            col1=strip(put(coalesce(r_base_median,0),&desc_statfmt)); col2=strip(put(coalesce(t_base_median,0),&desc_statfmt)); col3=strip(put(coalesce(a_base_median,0),&desc_statfmt)); output;
            page=1; order=1; index=5; col0='   Min, Max';
            col1=cats(strip(put(coalesce(r_base_min,0),&desc_statfmt)),', ',strip(put(coalesce(r_base_max,0),&desc_statfmt)));
            col2=cats(strip(put(coalesce(t_base_min,0),&desc_statfmt)),', ',strip(put(coalesce(t_base_max,0),&desc_statfmt)));
            col3=cats(strip(put(coalesce(a_base_min,0),&desc_statfmt)),', ',strip(put(coalesce(a_base_max,0),&desc_statfmt))); output;

            page=1; order=2; index=1; col0="%superq(desc_aval_label)"; col1=''; col2=''; col3=''; output;
            page=1; order=2; index=2; col0='   n';
            col1=strip(put(coalesce(r_aval_n,0),&desc_nfmt)); col2=strip(put(coalesce(t_aval_n,0),&desc_nfmt)); col3=strip(put(coalesce(a_aval_n,0),&desc_nfmt)); output;
            page=1; order=2; index=3; col0='   Mean (SD)';
            col1=cats(strip(put(coalesce(r_aval_mean,0),&desc_statfmt)),' (',strip(put(coalesce(r_aval_sd,0),&desc_statfmt)),')');
            col2=cats(strip(put(coalesce(t_aval_mean,0),&desc_statfmt)),' (',strip(put(coalesce(t_aval_sd,0),&desc_statfmt)),')');
            col3=cats(strip(put(coalesce(a_aval_mean,0),&desc_statfmt)),' (',strip(put(coalesce(a_aval_sd,0),&desc_statfmt)),')'); output;
            page=1; order=2; index=4; col0='   Median';
            col1=strip(put(coalesce(r_aval_median,0),&desc_statfmt)); col2=strip(put(coalesce(t_aval_median,0),&desc_statfmt)); col3=strip(put(coalesce(a_aval_median,0),&desc_statfmt)); output;
            page=1; order=2; index=5; col0='   Min, Max';
            col1=cats(strip(put(coalesce(r_aval_min,0),&desc_statfmt)),', ',strip(put(coalesce(r_aval_max,0),&desc_statfmt)));
            col2=cats(strip(put(coalesce(t_aval_min,0),&desc_statfmt)),', ',strip(put(coalesce(t_aval_max,0),&desc_statfmt)));
            col3=cats(strip(put(coalesce(a_aval_min,0),&desc_statfmt)),', ',strip(put(coalesce(a_aval_max,0),&desc_statfmt))); output;

            page=1; order=3; index=1; col0="%superq(desc_chg_label)"; col1=''; col2=''; col3=''; output;
            page=1; order=3; index=2; col0='   n';
            col1=strip(put(coalesce(r_chg_n,0),&desc_nfmt)); col2=strip(put(coalesce(t_chg_n,0),&desc_nfmt)); col3=strip(put(coalesce(a_chg_n,0),&desc_nfmt)); output;
            page=1; order=3; index=3; col0='   Mean (SD)';
            col1=cats(strip(put(coalesce(r_chg_mean,0),&desc_statfmt)),' (',strip(put(coalesce(r_chg_sd,0),&desc_statfmt)),')');
            col2=cats(strip(put(coalesce(t_chg_mean,0),&desc_statfmt)),' (',strip(put(coalesce(t_chg_sd,0),&desc_statfmt)),')');
            col3=cats(strip(put(coalesce(a_chg_mean,0),&desc_statfmt)),' (',strip(put(coalesce(a_chg_sd,0),&desc_statfmt)),')'); output;
            page=1; order=3; index=4; col0='   Median';
            col1=strip(put(coalesce(r_chg_median,0),&desc_statfmt)); col2=strip(put(coalesce(t_chg_median,0),&desc_statfmt)); col3=strip(put(coalesce(a_chg_median,0),&desc_statfmt)); output;
            page=1; order=3; index=5; col0='   Min, Max';
            col1=cats(strip(put(coalesce(r_chg_min,0),&desc_statfmt)),', ',strip(put(coalesce(r_chg_max,0),&desc_statfmt)));
            col2=cats(strip(put(coalesce(t_chg_min,0),&desc_statfmt)),', ',strip(put(coalesce(t_chg_max,0),&desc_statfmt)));
            col3=cats(strip(put(coalesce(a_chg_min,0),&desc_statfmt)),', ',strip(put(coalesce(a_chg_max,0),&desc_statfmt))); output;
        %end;

        page=2; order=10; index=1; col0='Adjusted Estimates (ANCOVA Model)'; col1=''; col2=''; col3=''; output;

        page=2; order=10; index=2; col0='   LS Mean (SE)';
        if "&_mockshell"='Y' then do;
            col1='xx.xx (x.x)';
            col2='xx.xx (x.x)';
        end;
        else do;
            col1=cats(strip(put(test_lsm,&meanfmt)), ' (',strip(put(test_se,&sefmt)),')');
            col2=cats(strip(put(ref_lsm,&meanfmt)), ' (',strip(put(ref_se,&sefmt)),')');
        end;
        col3=''; output;

        page=2; order=10; index=3; col0='   95% CI';
        if "&_mockshell"='Y' then do;
            col1='(xx.xx, xx.xx)';
            col2='(xx.xx, xx.xx)';
        end;
        else do;
            col1=cats('(',strip(put(test_lcl,&meanfmt)) ,', ',strip(put(test_ucl,&meanfmt)),')');
            col2=cats('(',strip(put(ref_lcl,&meanfmt)) ,', ',strip(put(ref_ucl,&meanfmt)),')');
        end;
        col3=''; output;

        page=2; order=11; index=1; col0='LS Mean Difference'; col1=''; col2=''; col3=''; output;

        page=2; order=11; index=2; col0="   'Active - Placebo' (SE)";
        if "&_mockshell"='Y' then col1='xx.xx (x.x)';
        else col1=cats(strip(put(diff_est,&meanfmt)),' (',strip(put(diff_se,&sefmt)),')');
        col2=''; col3=''; output;

        page=2; order=11; index=3; col0='   95% CI';
        if "&_mockshell"='Y' then col1='(xx.xx, xx.xx)';
        else col1=cats('(',strip(put(diff_lcl,&meanfmt)), ', ',strip(put(diff_ucl,&meanfmt)),')');
        col2=''; col3=''; output;

        page=2; order=12; index=4; col0='   p-value';
        if "&_mockshell"='Y' then col1='x.xxx';
        else if not missing(diff_pval) and diff_pval < 0.001 then col1='<0.001';
        else if missing(diff_pval) then col1='';
        else col1=strip(put(diff_pval,&pfmt));
        col2=''; col3=''; output;

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
            %put WARNING: ars_ancova_make_output - LIBREF OUTPUT is not assigned. Unable to create OUTPUT.&refno..;
        %end;
    %end;

    proc datasets lib=work nolist;
        delete _anc_src _anc_src_s _anc_lsm _anc_test _anc_ref _anc_diff_pool _anc_diff _anc_one _anc_final
               _anc_desc_in _anc_desc_stats _anc_desc_test _anc_desc_ref _anc_desc_tot _anc_desc_one;
    quit;

%mend ars_ancova_make_output;

/*--------------------------------------------------------------------------
Example driver snippet
---------------------------------------------------------------------------
%ars_ancova_make_output(
    arsds=work.ars_results_long,
    out=work.page2_adj,
    test_value=AON-D21,
    ref_value=Placebo,
    test_hdr=AON-D21,
    ref_hdr=Placebo,
    pop_dsin=derived.adeff(where=(PARAMCD='MCHGSF7' and MITTFL='Y')),
    pop_byvar=TRTAN,
    pop_subject=USUBJID,
    pop_maxcols=2,
    pop_test_col=1,
    pop_ref_col=2,
    n_test=3,
    n_ref=2,
    n_total=5,
    paramcd=SFCHG,
    avisit=Day 7,
    display_id=T13_2_4_1,
    meanfmt=8.2,
    sefmt=8.1,
    pfmt=pvalue6.3,
    mockshell=N
);

* Optional report2 integration (3 display columns: active, placebo, total);
%alignl1(dsin=work.page2_adj, out=work.page2_adj_i5, alignall=YES, indentf=5, tidyup=YES);

data incolw;
    lev=1; output;
    lev=2; output;
    lev=3; output;
run;

%report2(
    dsin     = work.page2_adj_i5,
    cols     = page order index col0 col1 col2 col3,
    widths   = col0 44 col1 24 col2 24 col3 16
);
*/
