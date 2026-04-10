/****************************************************************************
* Program: ars_ancova_main_effect_example_driver.sas
* Purpose: Example main-effect ANCOVA driver showing new descriptive-stat
*          section support (Baseline / AVAL / CHG) and 4-column report output.
****************************************************************************/

%include "S:\Q_166\Q_ 04354\S-D21-C300\Prog_Stat\Development\Code\Utilities\autoexec.sas";

/* Use repo paths while developing locally; switch to study utility paths for PROD */
%include "C:\Users\karen.ooms.QUANTICATE\Documents\GitHub\Q_166_Q_04454\ars_ancova_production_analysis.sas";
%include "C:\Users\karen.ooms.QUANTICATE\Documents\GitHub\Q_166_Q_04454\ars_ancova_make_output.sas";
%include "C:\Users\karen.ooms.QUANTICATE\Documents\GitHub\Q_166_Q_04454\ars_ancova_report_output_to_txt.sas";

%let progname=PROD_ANCOVA_ARS_MAIN;

/*-----------------------------------------------------------------------------
 Example: ANCOVA main effect for SF ratio change at Day 7 (CE population)
 Notes:
   - This is an example/template driver for local validation.
   - Replace dataset paths and variable names to match your study standards.
   - The flow mirrors production wrappers:
       1) %ars_ancova_production_analysis
       2) %ars_ancova_make_output
       3) %ars_ancova_report_output_to_txt
-----------------------------------------------------------------------------*/
%macro ANALYSEIT_ANCOVA_MAIN(
    refno=,
    pop=CEFL,
    paramcd=MCHGSF7,
    paramlbl=%str(Change from Baseline in S/F Ratio at Day 7),
    avisit=%str(Day 7),
    avisitn=7,
    test_value=%str(AON-D21),
    ref_value=%str(Placebo),
    debug_print=N
);

    /*-----------------------------------------------------------------------
      Step 1: Run model + normalize ODS outputs into ARS long format.
      Here we run NONREPEATED ANCOVA on CHG at one visit.
      IMPORTANT:
        - `analysis_var=CHG` is correct for the ANCOVA model.
        - `baseline_var=BASE` is the model covariate.
        - `AVAL` is NOT a model term here; it is used later in Step 2
          for descriptive summaries via `desc_aval_var=AVAL`.
    -----------------------------------------------------------------------*/
    %ars_ancova_production_analysis(
        adam=derived.adeff,
        out=work.ars_main_anc_&paramcd._&pop,
        subject_var=USUBJID,
        trt_var=TRT01P,
        visit_var=AVISIT,
        visitn_var=AVISITN,
        param_var=PARAMCD,
        param_label_var=PARAM,
        analysis_var=CHG,
        baseline_var=BASE,
        analysis_mode=NONREPEATED,
        where_clause=(PARAMCD="&paramcd" and &pop='Y' and AVISITN=&avisitn),
        reporting_event_id=RE_ANC_MAIN,
        method_id=MTH_ANCOVA,
        display_id=&refno,
        debug_print=&debug_print
    );

    /*-----------------------------------------------------------------------
      Step 2: Build table-shaped output rows.
      - Includes optional descriptive sections (baseline / aval / change).
      - Also writes OUTPUT.&refno if OUTPUT libref is assigned.
    -----------------------------------------------------------------------*/
    %ars_ancova_make_output(
        arsds=work.ars_main_anc_&paramcd._&pop,
        out=work.out_main_anc_&paramcd._&pop,
        test_value=&test_value,
        ref_value=&ref_value,
        test_hdr=&test_value,
        ref_hdr=&ref_value,

        /* Optional permanent dataset export */
        refno=&refno,

        /* Filters for model-based rows */
        display_id=&refno,
        paramcd=&paramcd,
        param=&paramlbl,
        avisit=&avisit,
        avisitn=&avisitn,

        /* Descriptive sections shown before ANCOVA model rows.
           This is where BASE / AVAL / CHG are explicitly selected. */
        include_desc_stats=Y,
        desc_dsin=derived.adeff(where=(PARAMCD="&paramcd" and &pop='Y' and AVISITN=&avisitn)),
        desc_trt_var=TRT01P,
        desc_base_var=BASE,
        desc_aval_var=AVAL,
        desc_chg_var=CHG,
        desc_base_label=%str(S/F Ratio at Baseline),
        desc_aval_label=%str(S/F Ratio at Day 7),
        desc_chg_label=%str(Change from Baseline to Day 7),
        desc_nfmt=8.,
        desc_statfmt=8.1,

        meanfmt=8.2,
        sefmt=8.1,
        pfmt=pvalue6.3,
        mockshell=N
    );

    /*-----------------------------------------------------------------------
      Step 3: Build standard footnotes/header globals for report2 output.
    -----------------------------------------------------------------------*/
    %mindex3(refno=&refno., progname=&progname., tidyup=NO, appfoot=NO);

    /*-----------------------------------------------------------------------
      Step 4: Render the plain-text report.
      Uses 4 columns: COL0 label + Placebo + AON-D21 + Total.
    -----------------------------------------------------------------------*/
    %ars_ancova_report_output_to_txt(
        dsin=work.out_main_anc_&paramcd._&pop,
        pop=&pop,
        outd=&studydir.Outputs,
        outf=&refno..txt,
        linesize=125,
        pagesize=43,
        cols=page order index col0 col1 col2 col3,
        widths=col0 44 col1 24 col2 24 col3 16,
        w0=44,
        w1=24,
        col0txt=
    );

%mend ANALYSEIT_ANCOVA_MAIN;

/*-----------------------------------------------------------------------------
 Example invocation
-----------------------------------------------------------------------------*/
%ANALYSEIT_ANCOVA_MAIN(
    refno=TEFF_ANC_EX1,
    pop=CEFL,
    paramcd=MCHGSF7,
    paramlbl=%str(Change from Baseline in S/F Ratio at Day 7),
    avisit=%str(Day 7),
    avisitn=7,
    test_value=%str(AON-D21),
    ref_value=%str(Placebo),
    debug_print=N
);
