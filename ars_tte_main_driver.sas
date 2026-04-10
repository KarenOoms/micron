/****************************************************************************
* Program: ars_tte_main_driver.sas
* Purpose: Outline driver for main-effect TTE outputs using ARS wrapper macros
*          (Cox PH + Kaplan-Meier), aligned to the same style as ANCOVA flow.
*
* Flow
*   Step 1: %ars_tte_production_analysis
*   Step 2: %ars_tte_make_output
*   Step 3: %ars_ancova_report_output_to_txt
****************************************************************************/

%include "S:\Q_166\Q_ 04354\S-D21-C300\Prog_Stat\Development\Code\Utilities\autoexec.sas";

%include "S:\Q_166\Q_ 04354\S-D21-C300\Prog_Stat\Development\Code\Utilities\ars_tte_production_analysis.sas";
%include "S:\Q_166\Q_ 04354\S-D21-C300\Prog_Stat\Development\Code\Utilities\ars_tte_make_output.sas";
%include "S:\Q_166\Q_ 04354\S-D21-C300\Prog_Stat\Development\Code\Utilities\ars_ancova_report_output_to_txt.sas";

%let progname=PROD_TTE_ARS_MAIN;

/* Optional subgroup/covariate pull from ADSL, mirroring your continuous driver style */
data tte_cov;
    set derived.adsl(keep=USUBJID BASESF AGEGR1 RESPTYPE BLVASOFL CEFL CRPGR1 CRPGR2 RESPGR1 BPFGR1 BPFGR2);
run;

proc sort data=tte_cov;
    by USUBJID;
run;

proc sort data=derived.adtte out=adtte;
    by USUBJID;
run;

data adtte2;
    merge tte_cov adtte;
    by USUBJID;
run;

%macro ANALYSEIT_TTE(
    refno=,
    pop=,
    resptype=,
    paramcd=,
    paramlbl=,
    dayx=28,
    event_desc=Time to Event
);

    /*
      Expected ADTTE assumptions in this template:
      - TIME variable:  AVAL (days)
      - Censor variable: CNSR (0=censored, 1=event)
      - Treatment var:  TRTP
      - Population flag: macro parameter POP (e.g., MITTFL)
    */

    %ars_tte_production_analysis(
        adam=adtte2,
        out=work.ars_main_tte_&paramcd._&pop,

        subject_var=USUBJID,
        trt_var=TRTP,
        paramcd_var=PARAMCD,
        param_var=PARAM,
        time_var=AVAL,
        censor_var=CNSR,
        censor_value=0,

        class_vars=AGEGR1 RESPTYPE BLVASOFL,
        covariates=BASESF AGEGR1 RESPTYPE BLVASOFL,

        where_clause=(PARAMCD="&paramcd" and &pop='Y' and RESPTYPE ne (&resptype)),

        km_timepoint=&dayx,
        test_value=%str(AON-D21),
        ref_value=%str(Placebo),

        reporting_event_id=RE_TTE_MAIN,
        method_id=MTH_COXPH_TTE,
        display_id=&refno,
        debug_print=N
    );

    %ars_tte_make_output(
        arsds=work.ars_main_tte_&paramcd._&pop,
        out=work.out_main_tte_&paramcd._&pop,
        test_value=%str(AON-D21),
        ref_value=%str(Placebo),
        test_hdr=%str(AON-D21),
        ref_hdr=%str(Placebo),
        day_label=&dayx,
        display_id=&refno,
        refno=&refno,
        paramcd=&paramcd,
        /* Keep PARAM filter blank if ADTTE PARAM text can vary across runs */
        param=%str(&paramlbl),
        strict_param=N,
        statfmt=8.2,
        sdfmt=8.1,
        pctfmt=8.1,
        hrfmt=8.3,
        pfmt=pvalue6.3,
        mockshell=N
    );

    /***Run MINDEX***/
    %mindex3(refno=&refno., progname=&progname., tidyup=NO, appfoot=NO);

    %ars_ancova_report_output_to_txt(
        dsin=work.out_main_tte_&paramcd._&pop,
        outd=&studydir.Outputs,
        outf=&refno..txt,
        linesize=125,
        pagesize=43,
        col0txt=
    );

%mend ANALYSEIT_TTE;

/* Example call: replace PARAMCD/PARAM text to your TTE endpoint */
%ANALYSEIT_TTE(
    refno=TEFF1,
    pop=MITTFL,
    resptype="",
    paramcd=TTRS,
    paramlbl=%str(Time to No Longer Requiring Respiratory Support),
    dayx=28,
    event_desc=%str(Time to Improvement)
);
