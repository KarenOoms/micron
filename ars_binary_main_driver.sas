/****************************************************************************
* Program: ars_binary_main_driver.sas
* Purpose: Outline driver for binary Fisher endpoint outputs using ARS wrappers
* Flow:
*   1) %ars_binary_production_analysis
*   2) %ars_binary_make_output
*   3) %ars_binary_report_output_to_txt
****************************************************************************/

%include "S:\Q_166\Q_ 04354\S-D21-C300\Prog_Stat\Development\Code\Utilities\autoexec.sas";

%include "S:\Q_166\Q_ 04354\S-D21-C300\Prog_Stat\Development\Code\Utilities\ars_binary_production_analysis.sas";
%include "S:\Q_166\Q_ 04354\S-D21-C300\Prog_Stat\Development\Code\Utilities\ars_binary_make_output.sas";
%include "S:\Q_166\Q_ 04354\S-D21-C300\Prog_Stat\Development\Code\Utilities\ars_binary_report_output_to_txt.sas";

%let progname=PROD_BINARY_ARS_MAIN;

/* Optional covariate merge pattern (mirrors existing wrapper drivers) */
data bin_cov;
    set derived.adsl(keep=USUBJID AGEGR1 RESPTYPE BLVASOFL);
run;

proc sort data=bin_cov;
    by USUBJID;
run;

proc sort data=derived.adeff out=adeff;
    by USUBJID;
run;

data adeff2;
    merge bin_cov adeff;
    by USUBJID;
run;

%macro ANALYSEIT_BIN(
    refno=,
    pop=,
    paramcd=,
    paramlbl=,
    dayx=28,
    event_value=Y,
    non_event_value=N,
    event_label=Received Newly Initiated RRT,
    non_event_label=Did not Receive Newly Initiated RRT,
    missing_label=Missing
);

    %ars_binary_production_analysis(
        adam=adeff2,
        out=work.ars_main_bin_&paramcd._&pop,
        subject_var=USUBJID,
        trt_var=TRT01P,
        paramcd_var=PARAMCD,
        param_var=PARAM,
        resp_var=AVALC,
        event_value=%superq(event_value),
        non_event_value=%superq(non_event_value),
        where_clause=(PARAMCD="&paramcd" and &pop='Y'),
        test_value=%str(AON-D21),
        ref_value=%str(Placebo),
        reporting_event_id=RE_BIN_MAIN,
        method_id=MTH_FISHER,
        display_id=&refno,
        debug_print=N
    );

    %ars_binary_make_output(
        arsds=work.ars_main_bin_&paramcd._&pop,
        out=work.out_main_bin_&paramcd._&pop,
        test_value=%str(AON-D21),
        ref_value=%str(Placebo),
        test_hdr=%str(AON-D21),
        ref_hdr=%str(Placebo),
        day_label=&dayx,
        event_label=%superq(event_label),
        non_event_label=%superq(non_event_label),
        missing_label=%superq(missing_label),
        display_id=&refno,
        refno=&refno,
        paramcd=&paramcd,
        /* Keep PARAM filter blank (or STRICT_PARAM=N) if endpoint label text varies */
        param=%str(&paramlbl),
        strict_param=N,
        countfmt=8.,
        pctfmt=8.1,
        orfmt=8.2,
        pfmt=pvalue6.3,
        mockshell=N
    );

    %mindex3(refno=&refno., progname=&progname., tidyup=NO, appfoot=NO);

    %ars_binary_report_output_to_txt(
        dsin=work.out_main_bin_&paramcd._&pop,
        pop=&pop,
        outd=&studydir.Outputs,
        outf=&refno..txt,
        linesize=125,
        pagesize=43,
        widths=col0 65 col1 27 col2 27,
        w0=65,
        w1=27,
        col0txt=
    );

%mend ANALYSEIT_BIN;

/* Example call: binary endpoint by Day 28 */
%ANALYSEIT_BIN(
    refno=TBIN1,
    pop=MITTFL,
    paramcd=RRTDAY28,
    paramlbl=%str(Newly Initiated RRT by Day 28),
    dayx=28,
    event_value=Y,
    non_event_value=N,
    event_label=%str(Received Newly Initiated RRT),
    non_event_label=%str(Did not Receive Newly Initiated RRT),
    missing_label=%str(Missing)
);
