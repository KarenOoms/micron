/****************************************************************************
* Program:      ars_ancova_report_output_to_txt.sas
* Macro:        %ars_ancova_report_output_to_txt
* Purpose:      Create plain-text table output for ANCOVA shaped data
*               using standard Quanticate reporting macros.
****************************************************************************/

%macro ars_ancova_report_output_to_txt(
    dsin=,
    outd=,
    outf=,
    col0txt=,
    linesize=&ls,
    pagesize=&ps,
    widths=col0 59 col1 30 col2 30,
    cols=page order index col0 col1 col2,
    drop_col3=Y,
    alignall=YES,
    indentf=12,
    tidyup=YES,
    use_colwidth3=Y,
    w0=59,
    w1=30,
    pagenum=Y,
    pagenum1=Protocol:,
    pagenum2=&tabno.,
    pagenum3=Protocol:
);

    %ars_report_output_to_txt(
        dsin=&dsin,
        outd=&outd,
        pop=&pop,
        RESPTYPE=&RESPTYPE,
        outf=&outf,
        col0txt=&col0txt,
        linesize=&linesize,
        pagesize=&pagesize,
        widths=&widths,
        cols=&cols,
        drop_col3=&drop_col3,
        alignall=&alignall,
        indentf=&indentf,
        tidyup=&tidyup,
        use_colwidth3=&use_colwidth3,
        w0=&w0,
        w1=&w1,
        pagenum=&pagenum,
        pagenum1=&pagenum1,
        pagenum2=&pagenum2,
        pagenum3=&pagenum3
    );

%mend ars_ancova_report_output_to_txt;

/*--------------------------------------------------------------------------
Example
---------------------------------------------------------------------------
%ars_ancova_report_output_to_txt(
    arsds=work.ars_results_long_sf_trta,
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
    paramcd=MCHGSF7,
    display_id=T_SF_RATIO,
    mockshell=N
);

%ars_ancova_report_output_to_txt(
    dsin=work.page2_adj,
    outd=&outdir,
    outf=&outfile,
    col0txt=,
    use_colwidth3=Y
);
*/
