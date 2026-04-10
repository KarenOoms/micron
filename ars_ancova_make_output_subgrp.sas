/****************************************************************************
* Program:      ars_ancova_make_output_subgrp.sas
* Macro:        %ars_ancova_make_output_subgrp
* Purpose:      Build report-ready ANCOVA output with subgroup sections
*               (e.g., Race) while preserving the same row structure used
*               in the overall ANCOVA table.
*
* Usage notes:
*   - This macro expects ARS long-form results as input (typically from
*     %ars_ancova_production_analysis with subgroup_analysis=Y).
*   - To include all analyzed variables in one output table, leave PARAMCD=
*     and PARAM= blank. The macro will emit:
*       1) Variable subtitle row: "Variable: <parameter>"
*       2) Subgroup title row: "<subgroup_title_prefix>: <subgroup_label>"
*       3) Interaction row: "<interaction_label>" with subgroup interaction p-value
*       4) Subgroup blocks (LS Means, Difference, CI, p-value)
*   - Use SUBGROUP_FMT= to map subgroup codes to display labels
*     (for example F -> Female, M -> Male via PROC FORMAT).
*
* Example:
*   proc format;
*       value $sexfmt 'F'='Female' 'M'='Male';
*   run;
*
*   %ars_ancova_make_output_subgrp(
*       arsds=work.ars_results_long_sex,
*       out=work.page_subgrp_all_vars,
*       subgroup_label=Sex,
*       subgroup_fmt=$sexfmt.,
*       subgroup_title_prefix=Subgroup,
*       interaction_label=Treatment-by-Sex Interaction p-value,
*       test_value=AON-D21,
*       ref_value=Placebo,
*       display_id=T_SF_RATIO
*   );
****************************************************************************/

%macro ars_ancova_make_output_subgrp(
    arsds=,
    out=,
    subgroup_var=RACE,
    subgroup_label=Race,
    test_value=,
    ref_value=,
    test_hdr=,
    ref_hdr=,
    paramcd=,
    param=,
    avisit=,
    avisitn=,
    display_id=,
    meanfmt=8.2,
    sefmt=8.1,
    pfmt=pvalue6.3,
    subgroup_fmt=,
    subgroup_title_prefix=Subgroup,
    interaction_label=Treatment-by-Subgroup Interaction p-value,
    mockshell=N,
    where_clause=
);
    %local _mockshell _n_non_overall;
    %let _mockshell=%upcase(%superq(mockshell));

    %if %superq(arsds)= or not %sysfunc(exist(&arsds)) %then %do;
        %put ERROR: ars_ancova_make_output_subgrp - ARSDS is required and must exist.;
        %return;
    %end;

    %if %superq(out)= %then %do;
        %put ERROR: ars_ancova_make_output_subgrp - OUT dataset is required.;
        %return;
    %end;

    data _anc_src;
        set &arsds;
        where 1=1
            %if %superq(display_id) ne %then and strip(display_id)=strip("%superq(display_id)");
            %if %superq(paramcd) ne %then and strip(parameter_cd)=strip("%superq(paramcd)");
            %if %superq(param) ne %then and strip(parameter)=strip("%superq(param)");
            %if %superq(avisit) ne %then and strip(avisit)=strip("%superq(avisit)");
            %if %superq(avisitn) ne %then and avisitn=%superq(avisitn);
            %if %superq(where_clause) ne %then and (&where_clause);
        ;

        length subgroup_level var_label $200;
        subgroup_level='Overall';
        var_label=coalescec(strip(parameter),strip(parameter_cd),'(Missing Parameter)');

        if upcase(strip(grouping_1_id))='SUBGROUP_LEVEL' then subgroup_level=coalescec(strip(grouping_1_value),'Overall');
        else if upcase(strip(grouping_2_id))='SUBGROUP_LEVEL' then subgroup_level=coalescec(strip(grouping_2_value),'Overall');
        else if upcase(strip(grouping_3_id))='SUBGROUP_LEVEL' then subgroup_level=coalescec(strip(grouping_3_value),'Overall');

        %if %superq(subgroup_fmt) ne %then %do;
            subgroup_level=coalescec(strip(put(strip(subgroup_level),&subgroup_fmt)),strip(subgroup_level));
        %end;

        if missing(subgroup_level) then subgroup_level='Overall';
    run;

    proc sql noprint;
        select count(distinct subgroup_level) into :_n_non_overall trimmed
        from _anc_src
        where upcase(strip(subgroup_level)) ne 'OVERALL';
    quit;

    %if %superq(_n_non_overall)= %then %let _n_non_overall=0;

    %if &_n_non_overall > 0 %then %do;
        data _anc_src;
            set _anc_src;
            if upcase(strip(subgroup_level)) ne 'OVERALL';
        run;
    %end;

    proc sort data=_anc_src out=_anc_src_s;
        by var_label subgroup_level descending result_sequence;
    run;

    data _anc_var_order;
        set _anc_src_s;
        by var_label;
        if first.var_label then do;
            var_order+1;
            output;
        end;
        keep var_label var_order;
    run;

    data _anc_level_order;
        set _anc_src_s;
        by var_label subgroup_level;
        if first.subgroup_level then do;
            level_order+1;
            output;
        end;
        keep var_label subgroup_level level_order;
    run;

    proc sql;
        create table _anc_interact as
        select var_label,
               max(result_numeric) as interact_pval
        from _anc_src_s
        where upcase(strip(operation_id))='OP_SUBGRP_INTERACT'
          and upcase(strip(operation_role))='PVALUE'
        group by var_label;

        create table _anc_lsm as
        select var_label,
               subgroup_level,
               treatment,
               upcase(strip(operation_role)) as operation_role length=20,
               result_numeric
        from _anc_src_s
        where not missing(treatment)
          and missing(contrast)
          and upcase(strip(operation_role)) in ('LSMEAN','SE','LCL','UCL');

        create table _anc_test as
        select var_label,
               subgroup_level,
               max(case when operation_role='LSMEAN' then result_numeric end) as test_lsm,
               max(case when operation_role='SE' then result_numeric end) as test_se,
               max(case when operation_role='LCL' then result_numeric end) as test_lcl,
               max(case when operation_role='UCL' then result_numeric end) as test_ucl
        from _anc_lsm
        where upcase(strip(treatment))=upcase(strip("%superq(test_value)"))
        group by var_label, subgroup_level;

        create table _anc_ref as
        select var_label,
               subgroup_level,
               max(case when operation_role='LSMEAN' then result_numeric end) as ref_lsm,
               max(case when operation_role='SE' then result_numeric end) as ref_se,
               max(case when operation_role='LCL' then result_numeric end) as ref_lcl,
               max(case when operation_role='UCL' then result_numeric end) as ref_ucl
        from _anc_lsm
        where upcase(strip(treatment))=upcase(strip("%superq(ref_value)"))
        group by var_label, subgroup_level;
    quit;

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

    proc sql;
        create table _anc_diff as
        select var_label,
               subgroup_level,
               max(case when upcase(operation_role)='ESTIMATE' then result_numeric end) as est_raw,
               max(case when upcase(operation_role)='SE' then result_numeric end) as se_raw,
               max(case when upcase(operation_role)='LCL' then result_numeric end) as lcl_raw,
               max(case when upcase(operation_role)='UCL' then result_numeric end) as ucl_raw,
               max(case when upcase(operation_role)='PVALUE' then result_numeric end) as pval_raw,
               max(_direction) as direction
        from _anc_diff_pool
        group by var_label, subgroup_level;

        create table _anc_one as
        select coalesce(t.var_label, r.var_label, d.var_label) as var_label length=200,
               coalesce(t.subgroup_level, r.subgroup_level, d.subgroup_level) as subgroup_level length=200,
               t.test_lsm, t.test_se, t.test_lcl, t.test_ucl,
               r.ref_lsm, r.ref_se, r.ref_lcl, r.ref_ucl,
               d.est_raw, d.se_raw, d.lcl_raw, d.ucl_raw, d.pval_raw, d.direction,
               i.interact_pval
        from _anc_test as t
        full join _anc_ref as r
            on t.var_label=r.var_label and t.subgroup_level=r.subgroup_level
        full join _anc_diff as d
            on coalesce(t.var_label, r.var_label)=d.var_label
           and coalesce(t.subgroup_level, r.subgroup_level)=d.subgroup_level
        left join _anc_interact as i
            on coalesce(t.var_label, r.var_label, d.var_label)=i.var_label;
    quit;

    proc sql;
        create table _anc_one2 as
        select a.*,
               l.level_order,
               v.var_order
        from _anc_one as a
        left join _anc_level_order as l
            on a.var_label=l.var_label and a.subgroup_level=l.subgroup_level
        left join _anc_var_order as v
            on a.var_label=v.var_label;
    quit;

    data _anc_one;
        set _anc_one2;

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

    proc sort data=_anc_one;
        by var_order var_label level_order subgroup_level;
    run;

    data &out;
        set _anc_one;
        by var_order var_label level_order subgroup_level;
        length col0 col1 col2 $200;
		length _col1_pval $30;
        length page order index _interact_pval_n _page 8;

        retain _order _page 0;
        if first.var_label then do;
		    _page+1;
			_interact_pval_n=interact_pval;
            if "&_mockshell"='Y' then _col1_pval='x.xxx';
            else if not missing(_interact_pval_n) and _interact_pval_n < 0.001 then _col1_pval='<0.001';
            else if missing(_interact_pval_n) then _col1_pval='';
            else _col1_pval=strip(put(_interact_pval_n,&pfmt));

            _order+1;
            page=1; order=_order; index=0; col0=cats('Variable: ',strip(var_label)); col1=''; col2=''; output;

            _order+1;
            page=_page; order=_order; index=0; col0=cats("&subgroup_title_prefix",': ',"&subgroup_label"); col1=''; col2=''; output;
            page=_page; order=_order; index=1; col0="&interaction_label";
			col1=_col1_pval;
            col2=''; output;
        end;

        if first.subgroup_level then do;
     		if not first.var_label then _page+1;
            _order+1;
            page=_page; order=_order; index=1;
            col0=cats("&subgroup_label",': ',strip(subgroup_level));
            col1=''; col2=''; output;
            page=_page; order=_order; index=2; col0='   Adjusted Estimates (ANCOVA Model)'; col1=''; col2=''; output;
            page=_page; order=_order; index=3; col0='      LS Mean (SE)';
            if "&_mockshell"='Y' then do;
                col1='xx.xx (x.x)'; col2='xx.xx (x.x)';
            end;
            else do;
                col1=cats(strip(put(test_lsm,&meanfmt)), ' (',strip(put(test_se,&sefmt)),')');
                col2=cats(strip(put(ref_lsm,&meanfmt)), ' (',strip(put(ref_se,&sefmt)),')');
            end;
            output;

            page=_page; order=_order; index=4; col0='      95% CI';
            if "&_mockshell"='Y' then do;
                col1='(xx.xx, xx.xx)'; col2='(xx.xx, xx.xx)';
            end;
            else do;
                col1=cats('(',strip(put(test_lcl,&meanfmt)),', ',strip(put(test_ucl,&meanfmt)),')');
                col2=cats('(',strip(put(ref_lcl,&meanfmt)),', ',strip(put(ref_ucl,&meanfmt)),')');
            end;
            output;

            page=_page; order=_order; index=5; col0='   LS Mean Difference'; col1=''; col2=''; output;
            page=_page; order=_order; index=6; col0="      'Active - Placebo' (SE)";
            if "&_mockshell"='Y' then col1='xx.xx (x.x)';
            else col1=cats(strip(put(diff_est,&meanfmt)),' (',strip(put(diff_se,&sefmt)),')');
            col2=''; output;

            page=_page; order=_order; index=7; col0='      95% CI';
            if "&_mockshell"='Y' then col1='(xx.xx, xx.xx)';
            else col1=cats('(',strip(put(diff_lcl,&meanfmt)),', ',strip(put(diff_ucl,&meanfmt)),')');
            col2=''; output;

            page=_page; order=_order; index=8; col0='      p-value';
            if "&_mockshell"='Y' then col1='x.xxx';
            else if not missing(diff_pval) and diff_pval < 0.001 then col1='<0.001';
            else if missing(diff_pval) then col1='';
            else col1=strip(put(diff_pval,&pfmt));
            col2=''; output;
        end;

        keep page order index col0 col1 col2;
    run;

    proc sort data=&out;
        by page order index;
    run;

    proc datasets lib=work nolist;
        delete _anc_src _anc_src_s _anc_level_order _anc_var_order _anc_interact _anc_lsm _anc_test _anc_ref _anc_diff_pool _anc_diff _anc_one2 _anc_one;
    quit;

%mend ars_ancova_make_output_subgrp;
