/****************************************************************************
* Program:      ars_binary_report_output_to_txt.sas
* Macro:        %ars_binary_report_output_to_txt
* Purpose:      Thin wrapper over existing ARS TXT reporter for binary outputs.
****************************************************************************/

%macro ars_binary_report_output_to_txt(
    dsin=,
    outd=,
    pop=,
    outf=,
    col0txt=,
    linesize=&ls,
    pagesize=&ps,
    widths=col0 65 col1 27 col2 27,
    w0=65,
    w1=27,
    indentf=12,
    indent=,
    pagenum=Y,
    pagenum1=Protocol:,
    pagenum2=&tabno.,
    pagenum3=Protocol:
);

    %ars_report_output_to_txt(
        dsin=&dsin,
        outd=&outd,
        pop=&pop,
        outf=&outf,
        col0txt=&col0txt,
        linesize=&linesize,
        pagesize=&pagesize,
        widths=&widths,
        w0=&w0,
        w1=&w1,
        indentf=&indentf,
        indent=&indent,
        pagenum=&pagenum,
        pagenum1=&pagenum1,
        pagenum2=&pagenum2,
        pagenum3=&pagenum3
    );

%mend ars_binary_report_output_to_txt;
