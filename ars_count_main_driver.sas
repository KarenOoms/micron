/****************************************************************************
* Program: ars_count_main_driver.sas
* Purpose: Driver for count endpoint outputs using ARS count wrappers
* Flow:
*   1) %ars_count_production_analysis
*   2) %ars_count_make_output
*   3) %ars_count_report_output_to_txt
****************************************************************************/

%include "S:\Q_166\Q_ 04354\S-D21-C300\Prog_Stat\Development\Code\Utilities\autoexec.sas";

%include "S:\Q_166\Q_ 04354\S-D21-C300\Prog_Stat\Development\Code\Utilities\ars_count_production_analysis.sas";
%include "S:\Q_166\Q_ 04354\S-D21-C300\Prog_Stat\Development\Code\Utilities\ars_count_make_output.sas";
%include "S:\Q_166\Q_ 04354\S-D21-C300\Prog_Stat\Development\Code\Utilities\ars_count_report_output_to_txt.sas";

%let progname=PROD_COUNT_ARS_MAIN;

/* Optional covariate merge pattern (mirrors existing wrapper drivers) */
data cnt_cov;
    set derived.adsl(keep=USUBJID MITTFL TRT01P);
run;

proc sort data=cnt_cov;
    by USUBJID;
run;

proc sort data=derived.adeff out=adeff;
    by USUBJID;
run;

data adeff_cnt;
    merge cnt_cov adeff;
    by USUBJID;
run;

%macro ANALYSEIT_COUNT(
    refno=,
    pop=,
    paramcd=,
    paramlbl=,
    endpoint_label=,
    aval_var=AVAL,
    dayx=28,
    death_var=,
    withdraw_var=,
    death_label=Number of Participants that Died up to Day,
    withdraw_label=Number of Participants that Withdrew up to Day,
    test_value=%str(AON-D21),
    ref_value=%str(Placebo),
    test_hdr=%str(AON-D21),
    ref_hdr=%str(Placebo),
    strict_param=N,
    debug_print=N
);

    %ars_count_production_analysis(
        adam=adeff_cnt,
        out=work.ars_main_cnt_&paramcd._&pop,
        subject_var=USUBJID,
        trt_var=TRT01P,
        paramcd_var=PARAMCD,
        param_var=PARAM,
        aval_var=&aval_var,
        death_var=&death_var,
        withdraw_var=&withdraw_var,
        where_clause=(PARAMCD="&paramcd" and &pop='Y'),
        test_value=&test_value,
        ref_value=&ref_value,
        reporting_event_id=RE_CNT_MAIN,
        method_id=MTH_WMW,
        display_id=&refno,
        debug_print=&debug_print
    );

    %ars_count_make_output(
        arsds=work.ars_main_cnt_&paramcd._&pop,
        out=work.out_main_cnt_&paramcd._&pop,
        test_value=&test_value,
        ref_value=&ref_value,
        endpoint_label=%superq(endpoint_label),
        day_label=&dayx,
        death_label=%superq(death_label),
        withdraw_label=%superq(withdraw_label),
        test_hdr=&test_hdr,
        ref_hdr=&ref_hdr,
        display_id=&refno,
        refno=&refno,
        paramcd=&paramcd,
        param=%str(&paramlbl),
        include_total=N,
        strict_param=&strict_param,
        nfmt=8.,
        statfmt=8.1,
        diff_fmt=8.2,
        pfmt=pvalue6.3,
        mockshell=N
    );

    %mindex3(refno=&refno., progname=&progname., tidyup=NO, appfoot=NO);

    %ars_count_report_output_to_txt(
        dsin=work.out_main_cnt_&paramcd._&pop,
        pop=&pop,
        outd=&studydir.Outputs,
        outf=&refno..txt,
        linesize=125,
        pagesize=43,
        widths=col0 65 col1 27 col2 27,
        w0=65,
        w1=27,
        indentf=1,
        col0txt=
    );

%mend ANALYSEIT_COUNT;

/* Example call: Respiratory Support-Free Days (RSFD) until Day 28 */
%ANALYSEIT_COUNT(
    refno=TCNT1,
    pop=MITTFL,
    paramcd=RSFD28,
    paramlbl=%str(Respiratory Support-Free Days (RSFD) until Day 28),
    endpoint_label=%str(RSFD),
    aval_var=AVAL,
    dayx=28,
    death_var=CEFL,
    withdraw_var=,
    death_label=%str(Number of Participants that Died up to Day),
    withdraw_label=%str(Number of Participants that Withdrew up to Day),
    test_value=%str(AON-D21),
    ref_value=%str(Placebo),
    test_hdr=%str(AON-D21),
    ref_hdr=%str(Placebo),
    strict_param=N,
    debug_print=N
);
