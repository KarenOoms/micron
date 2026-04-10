/****************************************************************************
* Program: ars_ancova_subgroup_race_driver.sas
* Purpose: Example end-to-end flow for ANCOVA subgroup (Race) reporting.
* Notes:
*   1) Runs production ANCOVA with subgroup interaction term.
*   2) Builds page dataset with subgroup headers in COL0.
*   3) Sends the page dataset to existing TXT report writer.
****************************************************************************/

%macro ars_ancova_subgroup_race_driver(
    adam=,
    outd=,
    outf=,
    test_value=AON-D21,
    ref_value=Placebo,
    test_hdr=AON-D21,
    ref_hdr=Placebo,
    paramcd=,
    display_id=,
    where_clause=,
    linesize=&ls,
    pagesize=&ps,
    pagenum1=Protocol:,
    pagenum2=&tabno.,
    pagenum3=Protocol:
);

    %ars_ancova_production_analysis(
        adam=&adam,
        out=work.ars_results_long_race,
        analysis_mode=NONREPEATED,
        subgroup_analysis=Y,
        subgroup_var=RACE,
        subgroup_label=Race,
        interaction_scope=OVERALL,
        where_clause=&where_clause,
        display_id=&display_id
    );

    %ars_ancova_make_output_subgrp(
        arsds=work.ars_results_long_race,
        out=work.page2_adj_race,
        subgroup_var=RACE,
        subgroup_label=Race,
        test_value=&test_value,
        ref_value=&ref_value,
        test_hdr=&test_hdr,
        ref_hdr=&ref_hdr,
        paramcd=&paramcd,
        display_id=&display_id
    );

    %ars_ancova_report_output_to_txt(
        dsin=work.page2_adj_race,
        outd=&outd,
        outf=&outf,
        col0txt=,
        linesize=&linesize,
        pagesize=&pagesize,
        pagenum=Y,
        pagenum1=&pagenum1,
        pagenum2=&pagenum2,
        pagenum3=&pagenum3
    );

%mend ars_ancova_subgroup_race_driver;
