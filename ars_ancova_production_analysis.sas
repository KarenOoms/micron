/*=============================================================================
Program:      ars_ancova_production_analysis.sas
Macro:        %ars_ancova_production_analysis
Purpose:      Run an MMRM via PROC MIXED and normalize ODS outputs into a
              canonical ARS-aligned long result dataset.
              Supports repeated and straightforward non-repeated analyses.

Design notes
------------
- One statistical value = one canonical output row.
- Canonical target: analysis -> results -> operation result.
- The macro separates:
  (1) model execution (PROC MIXED + ODS capture), and
  (2) normalization (ODS tables -> ARS_RESULTS_LONG schema).
- This makes it reusable for:
  - production ODS path,
  - future QC ODS path,
  - future table-extraction path.
=============================================================================*/

%macro _ars_append(base=, add=);
    %if %sysfunc(exist(&add)) %then %do;
        proc append base=&base data=&add force;
        run;
    %end;
%mend _ars_append;

%macro ars_ancova_production_analysis(
    adam=,
    out=ars_results_long,
    subject_var=USUBJID,
    trt_var=TRT01A,
    visit_var=AVISIT,
    visitn_var=AVISITN,
    param_var=PARAMCD,
    param_label_var=PARAM,
    analysis_var=CHG,
    baseline_var=BASE,
    class_vars=,
    fixed_effects=,
    repeated_effect=,
    repeated_subject=,
    analysis_mode=REPEATED,
    covariance_type=UN,
    ddfm=KR,
    alpha=0.05,
    lsmeans_effect=,
    subgroup_var=,
    subgroup_label=,
    subgroup_analysis=N,
    desc_stats=N,
    interaction_scope=OVERALL,
    where_clause=,
    reporting_event_id=,
    method_id=MTH_MMRM,
    display_id=,
	debug_print=Y
);

    %local _where _fixed _rep_effect _rep_subject _class_stmt _analysis_mode _lsm_effect
           _is_repeated _an_lsmean _an_diff _an_omni _op_lsmean _op_diff
           _subgrp_on _subgroup_label _interaction_scope _interaction_term _fixed_up _lsm_up
   		   _tests3_ds _dsid _rc _tests3_has_fvalue _tests3_has_f _debug_print
           _lsm_has_estimate _lsm_has_lsmean _lsm_has_stderr _lsm_has_stderror _lsm_has_se
           _lsm_has_lower _lsm_has_lowercl _lsm_has_upper _lsm_has_uppercl
           _diff_has_estimate _diff_has_diff _diff_has_stderr _diff_has_stderror _diff_has_se
           _diff_has_lower _diff_has_lowercl _diff_has_upper _diff_has_uppercl _diff_has_probt _diff_has_adjp;

    %let _analysis_mode=%upcase(%superq(analysis_mode));
    %let _interaction_scope=%upcase(%superq(interaction_scope));
	%let _debug_print=%upcase(%superq(debug_print));
	%put NOTE: ars_ancova_production_analysis version 2026-04-05b (tests3 primary, type3 fallback run only if tests3 missing;

    %if %superq(adam)= %then %do;
        %put ERROR: mmrm_prod_to_ars - ADAM dataset is required.;
        %return;
    %end;

    %if not %sysfunc(exist(&adam)) %then %do;
        %put ERROR: mmrm_prod_to_ars - Input dataset &adam does not exist.;
        %return;
    %end;

    %if &_analysis_mode ne REPEATED and &_analysis_mode ne NONREPEATED %then %do;
        %put ERROR: mmrm_prod_to_ars - ANALYSIS_MODE must be REPEATED or NONREPEATED.;
        %return;
    %end;

    %if %upcase(%superq(subgroup_analysis))=Y and %superq(subgroup_var) ne %then %let _subgrp_on=1;
    %else %let _subgrp_on=0;

    %if %superq(subgroup_label)= %then %let _subgroup_label=%superq(subgroup_var);
    %else %let _subgroup_label=%superq(subgroup_label);

    %if &_interaction_scope ne OVERALL and &_interaction_scope ne BYVISIT %then %let _interaction_scope=OVERALL;

    %let _where=%sysfunc(coalescec(%superq(where_clause),1));
    %let _rep_effect=%sysfunc(coalescec(%superq(repeated_effect),&visit_var));
    %let _rep_subject=%sysfunc(coalescec(%superq(repeated_subject),&subject_var));

    %if %superq(fixed_effects)= %then %do;
        %if &_analysis_mode=REPEATED %then %do;
            %if &_subgrp_on %then
                %let _fixed=&trt_var &visit_var &trt_var*&visit_var &subgroup_var &trt_var*&subgroup_var &subgroup_var*&visit_var &trt_var*&subgroup_var*&visit_var &baseline_var;
            %else
                %let _fixed=&trt_var &visit_var &trt_var*&visit_var &baseline_var;
        %end;
        %else %do;
            %if &_subgrp_on %then
                %let _fixed=&trt_var &subgroup_var &trt_var*&subgroup_var &baseline_var;
            %else
                %let _fixed=&trt_var &baseline_var;
        %end;
    %end;
    %else %let _fixed=&fixed_effects;

    /* Enforce subgroup*treatment modeling terms when subgroup mode is ON,
       even if a custom FIXED_EFFECTS list was supplied */
    %if &_subgrp_on %then %do;
        %let _fixed_up=%upcase(%sysfunc(compbl(&_fixed)));

        %if %index(&_fixed_up,%upcase(&subgroup_var))=0 %then
            %let _fixed=%sysfunc(compbl(&_fixed &subgroup_var));

        %if %index(&_fixed_up,%upcase(&trt_var*&subgroup_var))=0 %then
            %let _fixed=%sysfunc(compbl(&_fixed &trt_var*&subgroup_var));

        %if &_analysis_mode=REPEATED %then %do;
            %if %index(&_fixed_up,%upcase(&subgroup_var*&visit_var))=0 %then
                %let _fixed=%sysfunc(compbl(&_fixed &subgroup_var*&visit_var));

            %if %index(&_fixed_up,%upcase(&trt_var*&subgroup_var*&visit_var))=0 %then
                %let _fixed=%sysfunc(compbl(&_fixed &trt_var*&subgroup_var*&visit_var));
        %end;
    %end;

    %if &_analysis_mode=REPEATED %then %do;
        %let _is_repeated=1;
        %if &_subgrp_on %then
            %let _class_stmt=%sysfunc(compbl(&class_vars &subject_var &trt_var &visit_var &subgroup_var));
        %else
            %let _class_stmt=%sysfunc(compbl(&class_vars &subject_var &trt_var &visit_var));
    %end;
    %else %do;
        %let _is_repeated=0;
        %if &_subgrp_on %then
            %let _class_stmt=%sysfunc(compbl(&class_vars &subject_var &trt_var &subgroup_var));
        %else
            %let _class_stmt=%sysfunc(compbl(&class_vars &subject_var &trt_var));
    %end;

    %if %superq(lsmeans_effect)= %then %do;
        %if &_subgrp_on %then %do;
            %if &_analysis_mode=REPEATED %then %let _lsm_effect=&trt_var*&subgroup_var*&visit_var;
            %else %let _lsm_effect=&trt_var*&subgroup_var;
        %end;
        %else %do;
            %if &_analysis_mode=REPEATED %then %let _lsm_effect=&trt_var*&visit_var;
            %else %let _lsm_effect=&trt_var;
        %end;
    %end;
    %else %let _lsm_effect=&lsmeans_effect;

    /* Enforce subgroup-level LSMEANS effect structure when subgroup mode is ON */
    %if &_subgrp_on %then %do;
        %if &_analysis_mode=REPEATED %then %let _lsm_effect=&trt_var*&subgroup_var*&visit_var;
        %else %let _lsm_effect=&trt_var*&subgroup_var;
    %end;

    %if &_subgrp_on %then %do;
        %if &_analysis_mode=REPEATED %then %do;
            %let _an_lsmean=AN_MMRM_SUBGRP_LSMEAN;
            %let _an_diff=AN_MMRM_SUBGRP_DIFF;
            %let _an_omni=AN_MMRM_SUBGRP_INTERACT;
            %let _op_lsmean=OP_SUBGRP_LSMEAN_VISIT;
            %let _op_diff=OP_SUBGRP_DIFF_VISIT;
        %end;
        %else %do;
            %let _an_lsmean=AN_ANCOVA_SUBGRP_LSMEAN;
            %let _an_diff=AN_ANCOVA_SUBGRP_DIFF;
            %let _an_omni=AN_ANCOVA_SUBGRP_INTERACT;
            %let _op_lsmean=OP_SUBGRP_LSMEAN;
            %let _op_diff=OP_SUBGRP_DIFF;
        %end;
    %end;
    %else %do;
        %if &_analysis_mode=REPEATED %then %do;
            %let _an_lsmean=AN_MMRM_LSMEAN;
            %let _an_diff=AN_MMRM_DIFF;
            %let _an_omni=AN_MMRM_OMNI;
            %let _op_lsmean=OP_LSMEAN_VISIT;
            %let _op_diff=OP_DIFF_VISIT;
        %end;
        %else %do;
            %let _an_lsmean=AN_MIXED_LSMEAN;
            %let _an_diff=AN_MIXED_DIFF;
            %let _an_omni=AN_MIXED_OMNI;
            %let _op_lsmean=OP_LSMEAN;
            %let _op_diff=OP_DIFF;
        %end;
    %end;

    %if &_subgrp_on %then %do;
        %if &_analysis_mode=REPEATED and &_interaction_scope=BYVISIT %then
            %let _interaction_term=%upcase(&trt_var*&subgroup_var*&visit_var);
        %else
            %let _interaction_term=%upcase(&trt_var*&subgroup_var);
    %end;
    %else %let _interaction_term=;

    data &out;
        length source_system $8 reporting_event_id $80 analysis_id $40 method_id $40 operation_id $40 operation_role $20
               parameter_cd $40 parameter $200 avisit $200 treatment $200 contrast $400
               grouping_1_id $40 grouping_1_value $200 grouping_2_id $40 grouping_2_value $200 grouping_3_id $40 grouping_3_value $200
               result_char $200 raw_value $64 formatted_value $200 display_id $80 row_id $80 col_id $80 result_key $1000;
        length avisitn 8 result_numeric 8 result_sequence 8;
        stop;
    run;

    /*-----------------------------
      Metadata from analysis set
    -----------------------------*/
    data _mm_meta;
        set &adam(where=(&_where) obs=1 );
        length parameter_cd $40 parameter $200;
        parameter_cd=vvalue(&param_var);
        parameter=vvalue(&param_label_var);
        keep parameter_cd parameter;
    run;

    %if not %sysfunc(exist(_mm_meta)) %then %do;
        data _mm_meta;
            length parameter_cd $40 parameter $200;
            parameter_cd=''; parameter='';
            output;
        run;
    %end;

    /*-----------------------------
      Step 1: model execution
    -----------------------------*/

    ods exclude all;
    ods output close;
    ods output lsmeans=_mm_lsmeans
               diffs=_mm_diffs
               tests3=_mm_tests3;

    proc mixed data=&adam(where=(&_where)) method=reml;
        class &_class_stmt;
        model &analysis_var = &_fixed / solution ddfm=&ddfm;
        %if &_analysis_mode=REPEATED %then %do;
            repeated &_rep_effect / subject=&_rep_subject type=&covariance_type;
        %end;
        lsmeans &_lsm_effect / diff cl alpha=&alpha;
    run;

	ods output close;
    ods exclude none;

    /*-----------------------------
      Step 2: normalization layer
      ODS -> ARS_RESULTS_LONG
    -----------------------------*/
 %let _lsm_has_estimate=0;
    %let _lsm_has_lsmean=0;
    %let _lsm_has_stderr=0;
    %let _lsm_has_stderror=0;
    %let _lsm_has_se=0;
    %let _lsm_has_lower=0;
    %let _lsm_has_lowercl=0;
    %let _lsm_has_upper=0;
    %let _lsm_has_uppercl=0;
    %if %sysfunc(exist(_mm_lsmeans)) %then %do;
        %let _dsid=%sysfunc(open(_mm_lsmeans,i));
        %if &_dsid %then %do;
            %if %sysfunc(varnum(&_dsid,Estimate)) > 0 %then %let _lsm_has_estimate=1;
            %if %sysfunc(varnum(&_dsid,LSMean)) > 0 %then %let _lsm_has_lsmean=1;
            %if %sysfunc(varnum(&_dsid,StdErr)) > 0 %then %let _lsm_has_stderr=1;
            %if %sysfunc(varnum(&_dsid,StdError)) > 0 %then %let _lsm_has_stderror=1;
            %if %sysfunc(varnum(&_dsid,SE)) > 0 %then %let _lsm_has_se=1;
            %if %sysfunc(varnum(&_dsid,Lower)) > 0 %then %let _lsm_has_lower=1;
            %if %sysfunc(varnum(&_dsid,LowerCL)) > 0 %then %let _lsm_has_lowercl=1;
            %if %sysfunc(varnum(&_dsid,Upper)) > 0 %then %let _lsm_has_upper=1;
            %if %sysfunc(varnum(&_dsid,UpperCL)) > 0 %then %let _lsm_has_uppercl=1;
            %let _rc=%sysfunc(close(&_dsid));
        %end;
    %end;
    %let _diff_has_estimate=0;
    %let _diff_has_diff=0;
    %let _diff_has_stderr=0;
    %let _diff_has_stderror=0;
    %let _diff_has_se=0;
    %let _diff_has_lower=0;
    %let _diff_has_lowercl=0;
    %let _diff_has_upper=0;
    %let _diff_has_uppercl=0;
    %let _diff_has_probt=0;
    %let _diff_has_adjp=0;
    %if %sysfunc(exist(_mm_diffs)) %then %do;
        %let _dsid=%sysfunc(open(_mm_diffs,i));
        %if &_dsid %then %do;
            %if %sysfunc(varnum(&_dsid,Estimate)) > 0 %then %let _diff_has_estimate=1;
            %if %sysfunc(varnum(&_dsid,Diff)) > 0 %then %let _diff_has_diff=1;
            %if %sysfunc(varnum(&_dsid,StdErr)) > 0 %then %let _diff_has_stderr=1;
            %if %sysfunc(varnum(&_dsid,StdError)) > 0 %then %let _diff_has_stderror=1;
            %if %sysfunc(varnum(&_dsid,SE)) > 0 %then %let _diff_has_se=1;
            %if %sysfunc(varnum(&_dsid,Lower)) > 0 %then %let _diff_has_lower=1;
            %if %sysfunc(varnum(&_dsid,LowerCL)) > 0 %then %let _diff_has_lowercl=1;
            %if %sysfunc(varnum(&_dsid,Upper)) > 0 %then %let _diff_has_upper=1;
            %if %sysfunc(varnum(&_dsid,UpperCL)) > 0 %then %let _diff_has_uppercl=1;
            %if %sysfunc(varnum(&_dsid,Probt)) > 0 %then %let _diff_has_probt=1;
            %if %sysfunc(varnum(&_dsid,AdjP)) > 0 %then %let _diff_has_adjp=1;
            %let _rc=%sysfunc(close(&_dsid));
        %end;
    %end;



    /* Family 1: treatment-specific LS means by visit */
    %if %sysfunc(exist(_mm_lsmeans)) %then %do;
        data _ars_lsmeans;
            if _n_=1 then set _mm_meta;
            set _mm_lsmeans;

            length source_system $8 reporting_event_id $80 analysis_id $40 method_id $40 operation_id $40 operation_role $20
                   parameter_cd $40 parameter $200 avisit $200 treatment $200 contrast $400
                   grouping_1_id $40 grouping_1_value $200 grouping_2_id $40 grouping_2_value $200 grouping_3_id $40 grouping_3_value $200
                   result_char $200 raw_value $64 formatted_value $200 display_id $80 row_id $80 col_id $80 result_key $1000
                   _subgrp_level $200 _visit_key $200;
            length avisitn result_numeric result_sequence 8;

            source_system='PROD';
            reporting_event_id="%superq(reporting_event_id)";
            analysis_id="&_an_lsmean";
            method_id="%superq(method_id)";
            operation_id="&_op_lsmean";

            avisit=vvaluex("&visit_var");
            avisitn=input(vvaluex("&visitn_var"), ?? best32.);
            treatment=vvaluex("&trt_var");
             %if &_subgrp_on %then %do;
                _subgrp_level=strip(vvaluex("&subgroup_var"));
            %end;
            %else %do;
                _subgrp_level='';
            %end;
            contrast='';

            if &_subgrp_on then do;
                grouping_1_id='SUBGROUP_VAR';   grouping_1_value="&_subgroup_label";
                grouping_2_id='SUBGROUP_LEVEL'; grouping_2_value=strip(_subgrp_level);
                grouping_3_id='TREATMENT';      grouping_3_value=strip(treatment);
            end;
            else do;
                if &_is_repeated then do;
                    grouping_1_id='VISIT';      grouping_1_value=coalescec(strip(put(avisitn,best.-l)),strip(avisit));
                end;
                else do;
                    grouping_1_id='ANALYSIS';   grouping_1_value='OVERALL';
                    avisit=''; avisitn=.;
                end;
                grouping_2_id='TREATMENT';      grouping_2_value=strip(treatment);
                grouping_3_id='PARAMCD';        grouping_3_value=strip(parameter_cd);
            end;

            if not &_is_repeated then do; avisit=''; avisitn=.; end;

            display_id="%superq(display_id)";
            row_id='';
            col_id='';
            result_sequence=. ;
            _visit_key=coalescec(strip(put(avisitn,best.-l)),strip(avisit));

            array _role[4] $8 _temporary_ ('LSMEAN','SE','LCL','UCL');
            array _valc[4] $40 _temporary_;
            _valc[1]='';
            %if &_lsm_has_estimate %then %do;
                if missing(_valc[1]) then _valc[1]=strip(vvaluex('Estimate'));
            %end;
            %if &_lsm_has_lsmean %then %do;
                if missing(_valc[1]) then _valc[1]=strip(vvaluex('LSMean'));
            %end;

            _valc[2]='';
            %if &_lsm_has_stderr %then %do;
                if missing(_valc[2]) then _valc[2]=strip(vvaluex('StdErr'));
            %end;
            %if &_lsm_has_stderror %then %do;
                if missing(_valc[2]) then _valc[2]=strip(vvaluex('StdError'));
            %end;
            %if &_lsm_has_se %then %do;
                if missing(_valc[2]) then _valc[2]=strip(vvaluex('SE'));
            %end;

            _valc[3]='';
            %if &_lsm_has_lower %then %do;
                if missing(_valc[3]) then _valc[3]=strip(vvaluex('Lower'));
            %end;
            %if &_lsm_has_lowercl %then %do;
                if missing(_valc[3]) then _valc[3]=strip(vvaluex('LowerCL'));
            %end;

            _valc[4]='';
            %if &_lsm_has_upper %then %do;
                if missing(_valc[4]) then _valc[4]=strip(vvaluex('Upper'));
            %end;
            %if &_lsm_has_uppercl %then %do;
                if missing(_valc[4]) then _valc[4]=strip(vvaluex('UpperCL'));
            %end;
            do _i=1 to dim(_role);
                if not missing(_valc[_i]) then do;
                    operation_role=_role[_i];
                    result_numeric=input(_valc[_i], ?? best32.);
                    result_char=_valc[_i];
                    raw_value=strip(put(result_numeric,best32.-l));
                    formatted_value=_valc[_i];
                    if &_is_repeated then result_key=catx('|',analysis_id,operation_id,operation_role,strip(parameter_cd),strip(_visit_key),strip(grouping_1_value),strip(grouping_2_value),strip(grouping_3_value));
                    else result_key=catx('|',analysis_id,operation_id,operation_role,strip(parameter_cd),strip(grouping_1_value),strip(grouping_2_value),strip(grouping_3_value));
                    output;
                end;
            end;

            keep source_system reporting_event_id analysis_id method_id operation_id operation_role
                 parameter_cd parameter avisitn avisit treatment contrast
                 grouping_1_id grouping_1_value grouping_2_id grouping_2_value
                 grouping_3_id grouping_3_value
                 result_numeric result_char raw_value formatted_value
                 display_id row_id col_id result_key result_sequence;
        run;
        %_ars_append(base=&out, add=_ars_lsmeans);
    %end;

    /* Family 2: treatment differences by visit (estimate, CI, p-value) */
    %if %sysfunc(exist(_mm_diffs)) %then %do;
        data _ars_diffs;
            if _n_=1 then set _mm_meta;
            set _mm_diffs;

            length source_system $8 reporting_event_id $80 analysis_id $40 method_id $40
                   operation_id $40 operation_role $20 parameter_cd $40 parameter $200
                   avisit $200 treatment $200 contrast $400
                   grouping_1_id $40 grouping_1_value $200
                   grouping_2_id $40 grouping_2_value $200
                   grouping_3_id $40 grouping_3_value $200
                   result_char $200 raw_value $64 formatted_value $200
                   display_id $80 row_id $80 col_id $80 result_key $1000;
            length avisitn result_numeric result_sequence 8;

            length _trt_a _trt_b _est _lcl _ucl _pval $200;
            _trt_a=strip(vvaluex("&trt_var"));
            _trt_b=strip(coalescec(vvaluex("_&trt_var"),vvaluex('Effect')));
        _est='';
            %if &_diff_has_estimate %then %do;
                if missing(_est) then _est=strip(vvaluex('Estimate'));
            %end;
            %if &_diff_has_diff %then %do;
                if missing(_est) then _est=strip(vvaluex('Diff'));
            %end;

            _lcl='';
            %if &_diff_has_lower %then %do;
                if missing(_lcl) then _lcl=strip(vvaluex('Lower'));
            %end;
            %if &_diff_has_lowercl %then %do;
                if missing(_lcl) then _lcl=strip(vvaluex('LowerCL'));
            %end;

            _ucl='';
            %if &_diff_has_upper %then %do;
                if missing(_ucl) then _ucl=strip(vvaluex('Upper'));
            %end;
            %if &_diff_has_uppercl %then %do;
                if missing(_ucl) then _ucl=strip(vvaluex('UpperCL'));
            %end;

            _pval='';
            %if &_diff_has_probt %then %do;
                if missing(_pval) then _pval=strip(vvaluex('Probt'));
            %end;
            %if &_diff_has_adjp %then %do;
                if missing(_pval) then _pval=strip(vvaluex('AdjP'));
            %end;
            _se='';
            %if &_diff_has_stderr %then %do;
                if missing(_se) then _se=strip(vvaluex('StdErr'));
            %end;
            %if &_diff_has_stderror %then %do;
                if missing(_se) then _se=strip(vvaluex('StdError'));
            %end;
            %if &_diff_has_se %then %do;
                if missing(_se) then _se=strip(vvaluex('SE'));
            %end;
            %if &_subgrp_on %then %do;
                _subgrp_level=strip(vvaluex("&subgroup_var"));
            %end;
            %else %do;
                _subgrp_level='';
            %end;

            source_system='PROD';
            reporting_event_id="%superq(reporting_event_id)";
            analysis_id="&_an_diff";
            method_id="%superq(method_id)";
            operation_id="&_op_diff";

            avisit=vvaluex("&visit_var");
            avisitn=input(vvaluex("&visitn_var"), ?? best32.);
            treatment=_trt_a;
            contrast=catx(' - ',_trt_a,_trt_b);

            if &_subgrp_on then do;
                grouping_1_id='SUBGROUP_VAR';   grouping_1_value="&_subgroup_label";
                grouping_2_id='SUBGROUP_LEVEL'; grouping_2_value=strip(_subgrp_level);
                grouping_3_id='CONTRAST';       grouping_3_value=strip(contrast);
            end;
            else do;
                if &_is_repeated then do;
                    grouping_1_id='VISIT';      grouping_1_value=coalescec(strip(put(avisitn,best.-l)),strip(avisit));
                end;
                else do;
                    grouping_1_id='ANALYSIS';   grouping_1_value='OVERALL';
                    avisit=''; avisitn=.;
                end;
                grouping_2_id='CONTRAST';       grouping_2_value=strip(contrast);
                grouping_3_id='PARAMCD';        grouping_3_value=strip(parameter_cd);
            end;

            if not &_is_repeated then do; avisit=''; avisitn=.; end;

            display_id="%superq(display_id)";
            row_id='';
            col_id='';
            result_sequence=. ;
            _visit_key=coalescec(strip(put(avisitn,best.-l)),strip(avisit));

            operation_role='ESTIMATE';
            result_numeric=input(_est, ?? best32.);
            result_char=strip(_est);
            raw_value=strip(put(result_numeric,best32.-l));
            formatted_value=strip(_est);
            if &_is_repeated then result_key=catx('|',analysis_id,operation_id,operation_role,strip(parameter_cd),strip(_visit_key),strip(grouping_1_value),strip(grouping_2_value),strip(grouping_3_value));
            else result_key=catx('|',analysis_id,operation_id,operation_role,strip(parameter_cd),strip(grouping_1_value),strip(grouping_2_value),strip(grouping_3_value));
            output;

            if not missing(_lcl) then do;
                operation_role='LCL';
                result_numeric=input(_lcl, ?? best32.);
                result_char=strip(_lcl);
                raw_value=strip(put(result_numeric,best32.-l));
                formatted_value=strip(_lcl);
                if &_is_repeated then result_key=catx('|',analysis_id,operation_id,operation_role,strip(parameter_cd),strip(_visit_key),strip(grouping_1_value),strip(grouping_2_value),strip(grouping_3_value));
                else result_key=catx('|',analysis_id,operation_id,operation_role,strip(parameter_cd),strip(grouping_1_value),strip(grouping_2_value),strip(grouping_3_value));
                output;
            end;

            if not missing(_ucl) then do;
                operation_role='UCL';
                result_numeric=input(_ucl, ?? best32.);
                result_char=strip(_ucl);
                raw_value=strip(put(result_numeric,best32.-l));
                formatted_value=strip(_ucl);
                if &_is_repeated then result_key=catx('|',analysis_id,operation_id,operation_role,strip(parameter_cd),strip(_visit_key),strip(grouping_1_value),strip(grouping_2_value),strip(grouping_3_value));
                else result_key=catx('|',analysis_id,operation_id,operation_role,strip(parameter_cd),strip(grouping_1_value),strip(grouping_2_value),strip(grouping_3_value));
                output;
            end;

             if not missing(_se) then do;
                operation_role='SE';
      			result_numeric=input(_se, ?? best32.);
                result_char=strip(_se);
                raw_value=strip(put(result_numeric,best32.-l));
                formatted_value=strip(_se);
                if &_is_repeated then result_key=catx('|',analysis_id,operation_id,operation_role,strip(parameter_cd),strip(_visit_key),strip(grouping_1_value),strip(grouping_2_value),strip(grouping_3_value));
                else result_key=catx('|',analysis_id,operation_id,operation_role,strip(parameter_cd),strip(grouping_1_value),strip(grouping_2_value),strip(grouping_3_value));
                output;
            end;

            if not missing(_pval) then do;
                operation_role='PVALUE';
                result_numeric=input(_pval, ?? best32.);
                result_char=strip(_pval);
                raw_value=strip(put(result_numeric,best32.-l));
                formatted_value=strip(_pval);
                if &_is_repeated then result_key=catx('|',analysis_id,operation_id,operation_role,strip(parameter_cd),strip(_visit_key),strip(grouping_1_value),strip(grouping_2_value),strip(grouping_3_value));
                else result_key=catx('|',analysis_id,operation_id,operation_role,strip(parameter_cd),strip(grouping_1_value),strip(grouping_2_value),strip(grouping_3_value));
                output;
            end;

            keep source_system reporting_event_id analysis_id method_id operation_id operation_role
                 parameter_cd parameter avisitn avisit treatment contrast
                 grouping_1_id grouping_1_value grouping_2_id grouping_2_value grouping_3_id grouping_3_value
                 result_numeric result_char raw_value formatted_value
                 display_id row_id col_id result_key result_sequence;
        run;
        %_ars_append(base=&out, add=_ars_diffs);
    %end;

    %let _tests3_ds=;
    %if %sysfunc(exist(_mm_tests3)) %then %let _tests3_ds=_mm_tests3;
    %else %if %sysfunc(exist(_mm_type3)) %then %let _tests3_ds=_mm_type3;
    %let _tests3_has_fvalue=0;
    %let _tests3_has_f=0;
    %if %superq(_tests3_ds) ne %then %do;
        %let _dsid=%sysfunc(open(&_tests3_ds,i));
        %if &_dsid %then %do;
            %if %sysfunc(varnum(&_dsid,FValue)) > 0 %then %let _tests3_has_fvalue=1;
            %if %sysfunc(varnum(&_dsid,F)) > 0 %then %let _tests3_has_f=1;
            %let _rc=%sysfunc(close(&_dsid));
        %end;
    %end;

    %if %superq(_tests3_ds) ne %then %do;
        data _ars_omni;
            if _n_=1 then set _mm_meta;
            set &_tests3_ds;

            length source_system $8 reporting_event_id $80 analysis_id $40 method_id $40 operation_id $40 operation_role $20
                   parameter_cd $40 parameter $200 avisit $200 treatment $200 contrast $400
                   grouping_1_id $40 grouping_1_value $200 grouping_2_id $40 grouping_2_value $200 grouping_3_id $40 grouping_3_value $200
                   result_char $200 raw_value $64 formatted_value $200 display_id $80 row_id $80 col_id $80 result_key $1000
				   _effect _effect_norm _effect_terms _fval _pval _int_term1 _int_term2 $200;
            length avisitn result_numeric result_sequence _n_terms 8;

            _effect=strip(vvaluex('Effect'));
			%if &_tests3_has_fvalue %then %do;
                _fval=strip(vvaluex('FValue'));
            %end;
            %else %if &_tests3_has_f %then %do;
                _fval=strip(vvaluex('F'));
            %end;
            %else %do;
                _fval='';
            %end;
            _pval=coalescec(vvaluex('ProbF'),vvaluex('Probf'));


           _effect_norm=upcase(compress(strip(_effect),' '));
            _effect_terms=upcase(compbl(tranwrd(strip(_effect),'*',' ')));
            _n_terms=countw(_effect_terms,' ');
            if &_subgrp_on then do;
                _int_term1=upcase(compress(cats("&trt_var",'*',"&subgroup_var"),' '));
                _int_term2=upcase(compress(cats("&subgroup_var",'*',"&trt_var"),' '));
                %if &_analysis_mode=REPEATED and &_interaction_scope=BYVISIT %then %do;
                    if _n_terms ne 3 then delete;
                    if indexw(_effect_terms,upcase("&visit_var"),' ') = 0 then delete;
                    if indexw(_effect_terms,upcase("&trt_var"),' ') = 0 then delete;
                    if indexw(_effect_terms,upcase("&subgroup_var"),' ') = 0 then delete;
                %end;
                %else %do;
                    if _n_terms ne 2 then delete;
                    if _effect_norm ne _int_term1 and _effect_norm ne _int_term2 then delete;
                %end;
            end;

            source_system='PROD';
            reporting_event_id="%superq(reporting_event_id)";
            analysis_id="&_an_omni";
            method_id="%superq(method_id)";
            %if &_subgrp_on %then %do;
                operation_id='OP_SUBGRP_INTERACT';
            %end;
            %else %do;
                operation_id='OP_TESTS3';
            %end;

            avisit=''; avisitn=. ; treatment=''; contrast='';
            if &_subgrp_on then do;
                grouping_1_id='SUBGROUP_VAR'; grouping_1_value="&_subgroup_label";
                grouping_2_id='SUBGROUP_LEVEL'; grouping_2_value='INTERACTION';
                grouping_3_id='MODEL_TERM';     grouping_3_value=strip(_effect);
            end;
            else do;
                grouping_1_id='EFFECT';       grouping_1_value=strip(_effect);
                grouping_2_id='PARAMCD';      grouping_2_value=strip(parameter_cd);
                grouping_3_id='';             grouping_3_value='';
            end;

            display_id="%superq(display_id)";
            row_id='';
            col_id='';
            result_sequence=. ;

            if not missing(_fval) then do;
                operation_role='FTEST';
                result_numeric=input(_fval, ?? best32.);
                result_char=strip(_fval);
                raw_value=strip(put(result_numeric,best32.-l));
                formatted_value=strip(_fval);
                result_key=catx('|',analysis_id,operation_id,operation_role,strip(parameter_cd),strip(grouping_1_value),strip(grouping_2_value));
                output;
            end;

            if not missing(_pval) then do;
                operation_role='PVALUE';
                result_numeric=input(_pval, ?? best32.);
                result_char=strip(_pval);
                raw_value=strip(put(result_numeric,best32.-l));
                formatted_value=strip(_pval);
                result_key=catx('|',analysis_id,operation_id,operation_role,strip(parameter_cd),strip(grouping_1_value),strip(grouping_2_value));
                output;
            end;

            keep source_system reporting_event_id analysis_id method_id operation_id operation_role
                 parameter_cd parameter avisitn avisit treatment contrast
                 grouping_1_id grouping_1_value grouping_2_id grouping_2_value grouping_3_id grouping_3_value
                 result_numeric result_char raw_value formatted_value
                 display_id row_id col_id result_key result_sequence;
        run;
        %_ars_append(base=&out, add=_ars_omni);
    %end;

  %if &_debug_print=Y %then %do;
        %if %sysfunc(exist(_mm_tests3)) %then %do;
            title "DEBUG: _MM_TESTS3";
            proc print data=_mm_tests3;
            run;
        %end;
        %if %sysfunc(exist(_mm_meta)) %then %do;
            title "DEBUG: _MM_META";
            proc print data=_mm_meta;
            run;
        %end;
        %if %sysfunc(exist(_ars_omni)) %then %do;
            title "DEBUG: _ARS_OMNI";
            proc print data=_ars_omni;
            run;
        %end;
        title;
    %end;

    %if &_subgrp_on and %upcase(%superq(desc_stats))=Y %then %do;
        proc summary data=&adam(where=(&_where)) nway;
            class &subgroup_var &trt_var %if &_is_repeated %then &visit_var &visitn_var; ;
            var &analysis_var;
            output out=_mm_desc(drop=_type_ _freq_) n=n mean=mean std=sd median=median min=min max=max;
        run;

        data _ars_desc;
            if _n_=1 then set _mm_meta;
            set _mm_desc;

            length source_system $8 reporting_event_id $80 analysis_id $40 method_id $40 operation_id $40 operation_role $20
                   parameter_cd $40 parameter $200 avisit $200 treatment $200 contrast $400
                   grouping_1_id $40 grouping_1_value $200 grouping_2_id $40 grouping_2_value $200 grouping_3_id $40 grouping_3_value $200
                   result_char $200 raw_value $64 formatted_value $200 display_id $80 row_id $80 col_id $80 result_key $1000
                   _stat_name _visit_key $200;
            length avisitn result_numeric result_sequence 8;

            source_system='PROD';
            reporting_event_id="%superq(reporting_event_id)";
            analysis_id='AN_DESC_SUBGRP';
            method_id="%superq(method_id)";
            operation_id='OP_DESC_SUBGRP';
            treatment=vvalue(&trt_var);
            avisit=vvalue(&visit_var);
            avisitn=input(vvalue(&visitn_var), ?? best32.);
            contrast='';

            grouping_1_id='SUBGROUP_VAR';   grouping_1_value="&_subgroup_label";
            grouping_2_id='SUBGROUP_LEVEL'; grouping_2_value=vvalue(&subgroup_var);
            grouping_3_id='TREATMENT';      grouping_3_value=strip(treatment);
            display_id="%superq(display_id)";
            row_id='';
            col_id='';
            result_sequence=. ;

            array _vals[6] n mean sd median min max;
            array _names[6] $8 _temporary_ ('N','MEAN','SD','MEDIAN','MIN','MAX');
            do _i=1 to 6;
                operation_role=_names[_i];
                result_numeric=_vals[_i];
                result_char=strip(put(result_numeric,best32.-l));
                raw_value=strip(put(result_numeric,best32.-l));
                formatted_value=strip(put(result_numeric,best12.));
                _visit_key=coalescec(strip(put(avisitn,best.-l)),strip(avisit));
                if &_is_repeated then result_key=catx('|',analysis_id,operation_id,operation_role,strip(parameter_cd),strip(_visit_key),strip(grouping_1_value),strip(grouping_2_value),strip(grouping_3_value));
                else result_key=catx('|',analysis_id,operation_id,operation_role,strip(parameter_cd),strip(grouping_1_value),strip(grouping_2_value),strip(grouping_3_value));
                output;
            end;

            keep source_system reporting_event_id analysis_id method_id operation_id operation_role
                 parameter_cd parameter avisitn avisit treatment contrast
                 grouping_1_id grouping_1_value grouping_2_id grouping_2_value grouping_3_id grouping_3_value
                 result_numeric result_char raw_value formatted_value
                 display_id row_id col_id result_key result_sequence;
        run;

        %_ars_append(base=&out, add=_ars_desc);
    %end;

    proc sort data=&out;
        by result_key;
    run;

    data &out;
        set &out;
        by result_key;
        result_sequence=_n_;
    run;

/**/
/**/
/*    proc datasets lib=work nolist;*/
/*        delete _mm_: _ars_:;*/
/*    quit;*/

%mend ars_ancova_production_analysis;

/* Example calls
%ars_ancova_production_analysis(
    adam=adam.adchg,
    out=ars_results_subgrp_ancova,
    subject_var=USUBJID,
    trt_var=TRT01A,
    param_var=PARAMCD,
    param_label_var=PARAM,
    analysis_var=CHG,
    baseline_var=BASE,
    class_vars=AGEGR1 RESPBASE VASOBASE BASECAT3,
    fixed_effects=TRT01A BASE BASECAT3 TRT01A*BASECAT3 AGEGR1 RESPBASE VASOBASE,
    analysis_mode=NONREPEATED,
    lsmeans_effect=TRT01A*BASECAT3,
    subgroup_var=BASECAT3,
    subgroup_label=Baseline category (3 groups),
    subgroup_analysis=Y,
    desc_stats=Y,
    where_clause=(PARAMCD='CHG' and ANL01FL='Y' and AVISITN=8),
    reporting_event_id=RE_SUBGRP_WK8,
    method_id=MTH_ANCOVA_SUBGROUP,
    display_id=T14_2_3
);

%ars_ancova_production_analysis(
    adam=adam.adchg,
    out=ars_results_subgrp_mmrm,
    subject_var=USUBJID,
    trt_var=TRT01A,
    visit_var=AVISIT,
    visitn_var=AVISITN,
    param_var=PARAMCD,
    param_label_var=PARAM,
    analysis_var=CHG,
    baseline_var=BASE,
    class_vars=AGEGR1 RESPBASE VASOBASE BASECAT3 AVISIT,
    fixed_effects=TRT01A AVISIT BASE BASECAT3 TRT01A*AVISIT TRT01A*BASECAT3 BASECAT3*AVISIT TRT01A*BASECAT3*AVISIT AGEGR1 RESPBASE VASOBASE,
    repeated_effect=AVISIT,
    repeated_subject=USUBJID,
    analysis_mode=REPEATED,
    covariance_type=UN,
    ddfm=KR,
    lsmeans_effect=TRT01A*BASECAT3*AVISIT,
    subgroup_var=BASECAT3,
    subgroup_label=Baseline category (3 groups),
    subgroup_analysis=Y,
    desc_stats=Y,
    where_clause=(PARAMCD='CHG' and ANL01FL='Y'),
    reporting_event_id=RE_SUBGRP_MMRM,
    method_id=MTH_MMRM_SUBGROUP,
    display_id=T14_2_4
);
*/
