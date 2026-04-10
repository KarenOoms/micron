/****************************************************************************
* Program:      ars_count_report_output_to_txt.sas
* Macro:        %ars_count_report_output_to_txt
* Purpose:      Create plain-text table output for analysis shaped data
*               using standard Quanticate reporting macros.
****************************************************************************/

%macro ars_count_report_output_to_txt(
    dsin=,
    outd=,
	pop=,
    outf=,
    col0txt=,
    linesize=&ls,
    pagesize=&ps,
    widths=col0 65 col1 27 col2 27,
    cols=page order index col0 col1 col2,
    alignall=YES,
    indentf=1,
    tidyup=YES,
    use_colwidth3=Y,
    w0=65,
    w1=27,
    pagenum=Y,
    pagenum1=Protocol:,
    pagenum2=&tabno.,
    pagenum3=Protocol:
);

    %local _pagenum _use_colwidth3 _pop;
    %let _pagenum=%upcase(%superq(pagenum));
    %let _use_colwidth3=%upcase(%superq(use_colwidth3));
    %let _pop=%superq(pop);

    %if %superq(dsin)= %then %do;
        %put ERROR: ars_count_report_output_to_txt - DSIN is required.;
        %return;
    %end;

    %if not %sysfunc(exist(&dsin)) %then %do;
        %put ERROR: ars_count_report_output_to_txt - Dataset &dsin does not exist.;
        %return;
    %end;

    %if %superq(outd)= or %superq(outf)= %then %do;
        %put ERROR: ars_count_report_output_to_txt - OUTD and OUTF are required.;
        %return;
    %end;

    %if &_pagenum ne Y and &_pagenum ne N %then %do;
        %put ERROR: ars_count_report_output_to_txt - PAGENUM must be Y or N.;
        %return;
    %end;

    %if &_use_colwidth3 ne Y and &_use_colwidth3 ne N %then %do;
        %put ERROR: ars_count_report_output_to_txt - USE_COLWIDTH3 must be Y or N.;
        %return;
    %end;

  

   %repstart1(new=new, outd=&outd, outf=&outf);

   %global tot1 tot2;
   %let tot1=0;
   %let tot2=0;

   %if %length(%superq(_pop))>0 %then %do;
      %popcount5(
		    dsin    = derived.adsl(where=(&_pop="Y")),
		    byvar   = TRT01PN,
		    subject = usubjid,
		    maxcols = 2
		);
   %end;

	proc format library=library;
	*All codes given in the pop column of the index tab of the PPL should have an associated format value;
	*********************************
	* GENERAL FORMATS FOR MOCK UPS  *
	*********************************;
		value _colfmt
			1 = "AON-D21 |(N=&tot1)"
			2 = "Placebo |(N=&tot2)"
			;
	     run;



    %if &_use_colwidth3=Y %then %do;
        data work.incolw;
            lev=1; output;
            lev=2; output;
        run;

     %colwidth3(
            dsin     = work.incolw,
            grpvar   = lev,
            statcol  = NO,
            col10    = NO,
            linesize = &linesize,
            W0       = &w0,
            W1       = &w1,
			grpfmt   =_colfmt.
        );
    %end;
	%alignl1(
        dsin=&dsin,
        out=work.output,
		alignall=&alignall,
        tidyup=&tidyup,
		indentf=&indentf
    );

	    %report2(
	        dsin=work.output,
	        col0txt=&col0txt,
			widths   = &widths,
			cols     = &cols,
	        linesize=&linesize,
			addstr = ,
        pagesize=&pagesize,
		    addproc    =
            compute after _page_;
                line @1 "%sysfunc(repeat(_, &lls. - 1))";
                line @1 &footer2.;
                line @1 &footer3.;
                line @1 "Source Data: &source.";
                line @1 " ";
                line @1 &foot1.;
                line @1 &foot2.;
				line @1 &foot3.;
				line @1 &foot4.;
				line @1 &foot5.;
				line @1 &foot6.;
				line @1 &foot7.;
				line @1 &foot8.;
				line @1 &foot9.;
            endcomp;
    );
             
    proc printto;
    run;

    %if &_pagenum=Y %then %do;
        %pagenum5(
            input="&outd.\&outf.",
            output="&outd.\&outf.",
            pagenum1=&pagenum1,
            pagenum2=&pagenum2,
            pagenum3=&pagenum3,
            linesize=&linesize,
            replace=NO,
            tidyup=YES
        );
    %end;

	%repend1;
/*    proc datasets lib=work nolist;*/
/*        delete _anc_page2_i5 _anc_incolw;*/
/*    quit;*/

%mend ars_count_report_output_to_txt;

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
