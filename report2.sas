*****************************Quanticate******************************;
*                                                                   *;
*  MACRO NAME       : report2.sas                                   *;
*  AUTHOR           : Will Paget (WP)                               *;
*                                                                   *;
*  CREATION DATE    : 09MAY2014 (NREPORT1)                          *;
*  RELEASE DATE     : 21NOV2014 (NREPORT1)                          *;
*                                                                   *;
*  LOCATION         : Q:\Central Project Resources\Generic Macros   *;
*                     \Validated Macros                             *;
*                                                                   *;
*  ADAPTED FROM     : nreport1.sas                                  *;
*                                                                   *;
*  PURPOSE          : Create a standard reporting macro that also   *;
*                     allows reporting for Client 024 standards     *;
*                                                                   *;
*                                                                   *;
* MACRO PARAMETERS  :                                               *;
*           DSIN     - Input dataset                                *;
*           BYVAR    - Name of a by variable where a subtitle will  *;
*                      be  added for each level (e.g. lab           *;
*                      parameters)                                  *;
*           BYTXT    - If the by variable needs to be sorted        *;
*                      correctly BYVAR can be used to sort and      *;
*                      BYTXT can be the variable whose values are   *;
*                      displayed in the subtitles. Otherwise the    *;
*                      values of BYVAR are displayed.               *;
*           TOTAL    - The column header text for COL10             *;
*           COL0TXT  - The column header text for COL0              *;
*           SCOLTXT  - The column header text for STATCOL column    *;
*           TOPLINE  - Controls inclusion of repeating line at top  *;
*                      of PROC REPORT output.  (default is YES)     *;
*           LINESIZE - Line size of the report                      *;
*           PAGESIZE - Page size of the report                      *;
*           MAXCOLS  - Used to define the number for the overall    *;
*                      column. E.g. COL(MAXCOLS+1). The default     *;
*                      value is 9 and hence default overall column  *;
*                      is COL10.                                    *;
*            RTF     - Triggers settings for RTF files (Default is  *;
*                      NO)                                          *;
*           SAVEDSIN - Specifies whether the DSET dataset is saved  *;
*                      as a permanent dataset to aid QC.            *;
*            ADDSTR  - Allows the inclusion (on COL1-COLXX) in the  *;
*                      column headers of additional information:    *;
*                        BN – Includes column N as ‘(N=xx)’         *;
*                        NP – Includes string ‘n (%)’               *;
*                        NM – Includes string ‘n/M(%)’              *;
*            COLS    - If specified will be used to over-write the  *;
*                      default COLUMNS row of the PROC REPORT (which*;
*                      is created from COLWIDTH macros)             *;
*            WIDTHS  - If specified will be used to over-write the  *;
*                      default widths (which are created from       *;
*                      COLWIDTH macros).                            *;
*         RTFWIDTHS  - As per WIDTHS parameter but used in the      *;
*                      style(columns)={width=[XX]} part of the      *;
*                      PROC REPORT                                  *;
*           FORMATS  - If given a value this will be used to apply  *;
*                      formats to the variables specified.          *;
*            JUSTIFY - Aligns column headers as LEFT, RIGHT or      *;
*                      CENTER, see the specification document for   *;
*                      more details                                 *;
*            COLJUST - Used with JUSTIFY to specify the variables   *;
*                      (columns) where the justification should be  *;
*                      &JUSTIFY                                     *;
*            ADDPROC - Allows some additional functionality to be   *;
*                      added but ensure that this does not over-    *;
*                      write standard functionality of the macro    *;
*             IDCOLS - Should be used for reports that are too wide *;
*                      to fit on a single page. This specifies the  *;
*                      ID variables (PRINT and NOPRINT variables),  *;
*                      i.e. the variables that should be repeated on*;
*                      each page of the report                      *;
*           SPAC0COL - Should be used for reports that are too wide *;
*                      to fit on a single page. This specifies the  *;
*                      variables that will be given a spacing of 0. *;
*                      This should be the first non-ID variable on  *;
*                      each page.                                   *;
*                                                                   *;
*  OUTPUT FILES : None                                              *;
*                                                                   *;
*  ASSUMPTIONS :  To be used in conjunction with COLWIDTH and       *;
*                 (N)MINDEX macros.  See the specifications for     *;
*                 more details                                      *;
*                                                                   *;
*  EXAMPLE MACRO CALL : %report1(dsin=final, byvar=LBTESTCD,        *;
*        bytxt=LBTEST,total=Total,col0txt=,scoltxt=Statistic,       *;
*       linesize=&ls,pagesize=&ps)                                  *;
*                                                                   *;
*  NOTES : THIS PROGRAM MUST NOT BE ADAPTED FOR STUDY SPECIFIC      *;
*          ANALYSES. ANY CHANGES OR UPDATES REQUIRED MUST BE        *;
*          BE IDENTIFIED IN THE MACRO UPDATE LOG. ANY UPDATES MUST  *;
*          BE VALIDATED AS DEFINED IN 'SAS MACRO LIFE-CYCLE' SOP    *;
*          SOP PRG-SOP-005.                                         *;
*          THIS PROGRAM AND ASSOCIATED DATASETS SHOULD NOT BE       *;
*          PASSED ONTO ANY THIRD PARTIES EXCEPT REGULATORY          *;
*          AUTHORITIES.                                             *;
*                                                                   *;
*  NOTE: FURTHER INFORMATION ON THE SAS MACRO CAN BE FOUND IN       *;
*        THE MACRO SPECIFICATION DOCUMENT CONTAINED IN              *;
*Q:\Central Project Resources\Generic Macros\Specification Documents*;
*                                                                   *;
*  CHANGE HISTORY  (ENSURE THAT ANY UPDATES ARE REFERENCED IN THE   *;
*                  PROGRAM WITH PROGRAMMER INITIALS AND DATE)       *;
*                                                                   *;
*  USERID   | DATE       | CHANGE                                   *;
* ----------+------------+------------------------------------------*;
* williamp  | 29FEB2016  | Added ADDSTR, COLS, (RTF)WIDTHS and      *;
*           |            | ADDPROC macro parameters                 *;
*           |            | Removed COL0W and COL0W parameters       *;
*           |            | Any sections referring to the above      *;
*           |            | parameters are therefore amended, plus   *;
*           |            | the REPORT code                          *;
*           |            | Due to the number of updates time and    *;
*           |            | initials are not included for each update*;
* williamp  | 22MAR2016  | Address minor validation comments        *;
* williamp  | 25JUL2016  | Add IDCOLS, SPAC0COL parameters          *;
*********************************************************************;

%***************************************************************************************;
%*** NB: Other than macro variables used in calling the macro,                       ***;
%*** the following are needed or generated:                                          ***;
%***                                                                                 ***;
%*** from COLWIDTH macro                                                             ***;
%***   col10_1           - yes or no - overall column required or not (col10)        ***;
%***   statcol_1         - yes or no - statistic column (between col0 and col1       ***;
%***                         and called statcol) required or not                     ***;
%***   w0_1              - width of column 0                                         ***;
%***   w1_1              - width of all remaining columns - including col10          ***;
%***   group1-groupn     - resoving to 1 to n for col numbers                        ***;
%***   fullgrp1-fullgrpn - resoving to the corresponding column text for col headers ***;
%***                                                                                 ***;
%*** from project log:                                                               ***;
%***   Footnotes and source                                                          ***;
%***                                                                                 ***;
%*** from POPCOUNT or POPNUM macro:                                                  ***;
%***   tot1-tot10       - population totals                                          ***;
%***************************************************************************************;

%macro report2(dsin      	 =
                , byvar  	 =
                , bytxt  	 =
                , total  	 = Overall
                , col0txt	 =
                , scoltxt	 = Statistic
			   	, topline	 = YES
                , linesize	 = &ls
                , pagesize	 = &ps
                , maxcols 	 = 9
			    , rtf	  	 = NO
                , savedsin 	 = NO
			    , addstr  	 = BN
			    , cols	  	 = 
			    , widths  	 = 
			    , rtfwidths  = 
			    , formats 	 = 
			    , justify  	 = center
			    , coljust 	 = 
			    , addproc	 = 
			    , idcols	 = 
			    , spac0col	 = 
              );

    %*******************************************; 
    %*** Declare local macro variables       ***;
    %*******************************************;
    %local _mcol _colwrun _incpage _incord _colsfin _totallc _fcolstr _fprcol _totwdth _totrwdth;

	* Check whether the input dataset is from the work library and remove where statement etc;
	%let _dsinnm = %upcase( %scan(%bquote(&dsin), 1, %() );
	%if %index(%bquote(&_dsinnm), .) %then %do;
		%let _ldsinnm = %upcase( %scan(%bquote(&_dsinnm), 1, .) );
		%let _dsinnm = %upcase( %scan(%bquote(&_dsinnm), 2, .) );
	%end;
	%else %do;
		%let _ldsinnm = WORK;
		%let _dsinnm = %upcase(%bquote(&_dsinnm));
	%end;

	%*** Harmonise parameter values ***;
	%pcheckyn1(param = savedsin);
	%if &_skip = 1 %then %goto here;
	%pcheckyn1(param = rtf);
	%if &_skip = 1 %then %goto here;
	%pcheckyn1(param = topline);
	%if &_skip = 1 %then %goto here;

	%let addstr = %upcase(&addstr);

	%let widths = %cmpres( %upcase(&widths) );
	%let rtfwidths = %cmpres( %upcase(&rtfwidths) );
	%let formats = %cmpres( %upcase(&formats) );
	%let coljust = %cmpres( %upcase(&coljust) );

    %*** macro parameter checking ***;
    %if %bquote(&dsin)= %then %do;
        data _null_;
            put "ERR" "OR: Macro parameter DSIN has " "not been specified.";
        run;
        %goto here;
    %end;
    %else %if %sysfunc(exist(&_ldsinnm..&_dsinnm))=0 %then %do;
        data _null_;
            put "ERR" "OR: Dataset &dsin does not exist.";
        run;
        %goto here;
    %end;
    %if &linesize= %then %do;
        data _null_;
            put "ERR" "OR: Macro parameter LINESIZE has " "not been specified.";
        run;
        %goto here;
    %end;
    %if &pagesize= %then %do;
        data _null_;
            put "ERR" "OR: Macro parameter PAGESIZE has " "not been specified.";
        run;
        %goto here;
    %end;
    %if &rtf = NO and &rtfwidths ^= %then %do;
        data _null_;
            put "MGCH" "ECK: Macro parameter RTF is NO but macro parameter " "RTFWIDTHS is populated." ;
            put "MGCH" "ECK: Therefore " "RTFWIDTHS will be ignored." ;
        run;
    %end;
    %if %upcase(&justify) ^= LEFT and %upcase(&justify) ^= RIGHT and %upcase(&justify) ^= CENTER %then %do;
        data _null_;
            put "ERR" "OR: Macro parameter JUSTIFY has a value that is not valid." ;
        run;
        %goto here;
    %end;
	%if %bquote(&idcols) ^= and (%bquote(&widths) = or %bquote(&spac0col) = ) %then %do;
        data _null_;
            put "ERR" "OR: If macro parameter IDCOLS is specified then both WIDTHS and SPAC0COL must also be specified." ;
        run;
        %goto here;
    %end;
	%if %bquote(&spac0col) ^= and %bquote(&widths) = %then %do;
        data _null_;
            put "ERR" "OR: If macro parameter SPAC0COL is specified then WIDTHS must also be specified." ;
        run;
        %goto here;
    %end;

	%*** Dealing with non-existence of global macro variables defined ***;
    %if &sysver >= 9 %then %do ;
        %if %sysfunc(symglobl(col10_1)) = 0 or %sysfunc(symglobl(totcol)) = 0 or %sysfunc(symglobl(statcol_1)) = 0 %then %do ;
            %if %bquote(&cols) = or %bquote(&widths) = %then %do;
				%put %str(ERR)%STR(OR:) Macro COLWIDTH has not been run and macro parameters WIDTHS or COLS are blank so macro cannot work. ;
				%goto here;
			%end;
            %else %if "&rtf."="YES" and %bquote(&rtfwidths) = %then %do;
				%put %str(ERR)%STR(OR:) RTF is specified as YES yet macro RTFCOLWIDTH has not been run and;
				%put %str(ERR)%STR(OR:) macro parameters RTFWIDTHS or COLS are blank so macro cannot work. ;
				%goto here;
			%end;
			%else %do;
				%let _colwrun = NO; * Stops later reference to TOTCOL from running;
        	%end;
        %end;
        %if %sysfunc(symglobl(footer1)) = 0 %then %do ;
            %put %str(ERR)%STR(OR:) Macro parameter FOOTER1 does not exist. Either of the MINDEX or NMINDEX macros need to be run. ;
            %goto here;
        %end;
        %if %sysfunc(symglobl(rw0_1)) = 0 %then %do ;
            %if %bquote(&rtfwidths) = and &rtf=YES %then %do;
		        data _null_;
		            put "ERR" "OR: Macro parameter RTF is YES but neither" " RTFWIDTHS or RW0_1 are present." ;
		        run;
		        %goto here;
		    %end;
            %else %let rw0_1=;
        %end;
		%else %let rw0_1 = %scan(&rw0_1, 1, %nrstr(%%));; * Remove percentage sign;
        %if %sysfunc(symglobl(rw1_1)) = 0 %then %do ;
            %if %bquote(&rtfwidths) = and &rtf=YES %then %do;
		        data _null_;
		            put "ERR" "OR: Macro parameter RTF is YES but neither" " RTFWIDTHS or RW1_1 are present." ;
		        run;
		        %goto here;
		    %end;
            %else %let rw1_1=;
        %end;
		%else %let rw1_1 = %scan(&rw1_1, 1, %nrstr(%%));; * Remove percentage sign;
    %end;

	%*** set overall column ***;
    %let _mcol=%eval(&maxcols + 1); 

	%*** Create the additional column headers ***;
	%if &addstr ^= and %length(&addstr) ^= 2 and %length(&addstr) ^= 4 and %length(&addstr) ^= 6 %then %do;
        data _null_;
            put "ERR" "OR: Macro parameter ADDSTR contains options that are not valid";
            put "ERR" "OR: (should be a combination of BN NP and NM, see macro specifications).";
        run;
        %goto here;
    %end;
	%else %do;
		%local _addstr1 _addstr2 _addstr3 _resstr1 _resstr2 _resstr3 _resstr;

		* Separate the additional column header strings out;
		%if %length(&addstr) ge 2 %then %let _addstr1 = %substr(&addstr, 1, 2);
		%if %length(&addstr) ge 4 %then %let _addstr2 = %substr(&addstr, 3, 2);
		%if %length(&addstr) eq 6 %then %let _addstr3 = %substr(&addstr, 5, 2);

		* Specify each of the separate column header strings;
		%do _astot = 1 %to 3;
			* Create as a temporary value to be over-written later;
			%if &&_addstr&_astot = BN %then %let _resstr&_astot = |(N=%sysfunc( byte(219) )); 
			%else %if &&_addstr&_astot = NP %then %let _resstr&_astot = |n (%);
			%else %if &&_addstr&_astot = NM %then %let _resstr&_astot = |n/M(%);
			%else %if &&_addstr&_astot ^= %then %do;
		        data _null_;
		            put "ERR" "OR: Macro parameter ADDSTR contains options that are not valid";
		            put "ERR" "OR: (should be a combination of BN NP and NM, see macro specifications).";
		        run;
		        %goto here;
		    %end;
		%end;

		%let _resstr = &_resstr1 &_resstr2 &_resstr3;
	%end;
	%let spac0col = %cmpres( %upcase(&spac0col) );
	%let idcols = %cmpres( %upcase(&idcols) );
	%let _totcolsp0 = 0;

	%if %bquote(&cols) ^= %then %do;
		%local _fcolstr _cols _totd _dqmstr _sqmstr _ldsinnm _dsinnm _byvarinc _bytxtinc;
		%let _fcolstr = &cols;
		%let cols = %cmpres( %upcase(&cols) );
		%*** COLS SPECIFIED: Strip out brackets and quoted text from the COLS statement **;

		* Strip brackets and replace single/double quotes to avoid special character issues;
		%let _cols = _%sysfunc( tranwrd(%bquote(&cols), %str(%(), %str()) );
		%let _cols = %sysfunc( tranwrd(%bquote(&_cols), %str(%)), %str()) );
		%let _cols = %sysfunc( tranwrd(%bquote(&_cols), %str(%'), %str( %sysfunc( byte(217) ) )) );
		%let _cols = %sysfunc( tranwrd(%bquote(&_cols), %str(%"), %str( %sysfunc( byte(218) ) )) );

		* Strip out any text between double quotes;
		%do _dnum = 1 %to 101 %by 2;
			%let _colstr&_dnum = %scan(%bquote(&_cols), &_dnum, %sysfunc( byte(218) ));
			%if &_dnum ge 5 %then %do;
				%let _dnum1 = %eval(&_dnum - 2);
				%let _dnum2 = %eval(&_dnum - 4);
				%if %bquote(&&_colstr&_dnum) = and %bquote(&&_colstr&_dnum1) = and %bquote(&&_colstr&_dnum2) = %then %goto breakd;
			%end;
		%end;
	    %breakd: %let _totd = %eval(&_dnum - 4);
		%let _dqmstr = ;
		%do _dnum = 1 %to &_totd %by 2;
			%let _dqmstr = &_dqmstr %bquote(&&_colstr&_dnum);
		%end;

		* Strip out any text between single quotes;
		%do _snum = 1 %to 101 %by 2;
			%let _colstra&_snum = %scan(%bquote(&_dqmstr), &_snum, %sysfunc( byte(217) ));
			%if &_snum ge 5 %then %do;
				%let _snum1 = %eval(&_snum - 2);
				%let _snum2 = %eval(&_snum - 4);
				%if %bquote(&&_colstra&_snum) = and %bquote(&&_colstra&_snum1) = and %bquote(&&_colstra&_snum2) = %then %goto breaks;
			%end;
		%end;
	    %breaks: %let _totd = %eval(&_snum - 4);
		%let _sqmstr = ;
		%do _snum = 1 %to &_totd %by 2;
			%let _sqmstr = &_sqmstr %bquote(&&_colstra&_snum);
		%end;
		%let _colsfin = %substr(&_sqmstr, 2);
		%let _colsfin = %sysfunc( strip(&_colsfin) );
		%let _colsfin = %qcmpres(&_colsfin);

		%*** COLS SPECIFIED: Create each column name, type, width, rtf width and label as macro parameters;
		* Create widths as a string from the standards if it is not specified;
		%if %str(&widths) = %then %do;
			%let widths = COL0 &w0_1;
			%if %upcase(&statcol_1)=YES %then %let widths = &widths STATCOL &w1_1;
			%if &_colwrun ^= NO %then %do;
				%do _i = 1 %to &totcol;
					%let widths = &widths COL&&group&_i &w1_1;
				%end;
			%end;
		 	%if %upcase(&col10_1)=YES %then %let widths = &widths COL&_mcol &w1_1;
		%end;

		* Create rtfwidths as a string from the standards if it is not specified;
		%if &rtf = YES %then %do;
			%if %str(&rtfwidths) = %then %do;
				%let rtfwidths = COL0 &rw0_1;
				%if %upcase(&statcol_1)=YES %then %let rtfwidths = &rtfwidths STATCOL &rw1_1;
				%if &_colwrun ^= NO %then %do;
					%do _i = 1 %to &totcol;
						%let rtfwidths = &rtfwidths COL&&group&_i &rw1_1;
					%end;
				%end;
			 	%if %upcase(&col10_1)=YES %then %let rtfwidths = &rtfwidths COL&_mcol &rw1_1;
			%end;
		%end;

		* Create:
			_COLSFIN - string of all variable in the report
			_COLNAMEi - Column name (from 1 to number of columns)
			_COLJUSTi - Column justification as LEFT, RIGHT or CENTER. Driven by &JUSTIFY for treatment cols, LEFT otherwise (from 1 to number of columns)
			_COLTYPEi - Column type (print or noprint) (from 1 to number of columns)
			_COLWDTHi - Column width (from 1 to number of columns)
			_COLRWDTHi - Column rtf width (from 1 to number of columns)
			_COLLABLi - Column label (from 1 to number of columns)
			_COLIDi - Adds ID if it is in IDCOLS (from 1 to number of columns)
			_COLSPi - Adds spacing = 0 if it is in SPAC0COL column(from 1 to number of columns);

		%do _colnms = 1 %to 100;
			* Get column name: Select the first word from the columns string;
			%let _colname&_colnms = %scan(&_colsfin, &_colnms, %str( )); 
			%if &&_colname&_colnms = %then %goto breakc;

			* Get widths: Scan the widths string to find the associated width;
			%let _colwdth&_colnms = ;
			%do _wdths = 1 %to 199 %by 2;
				%if %scan(&widths, &_wdths, %str( )) = &&_colname&_colnms %then %let _colwdth&_colnms = %scan(&widths, %eval(&_wdths + 1), %str( ));
				%if %scan(&widths, &_wdths, %str( )) = or &&_colwdth&_colnms ^= %then %goto breakw;
			%end;
			%breakw:;

			%let _colfmt&_colnms = ;
			%if %nrbquote(&formats) ^= %then %do;
				* Get formats: Scan the formats string to find the associated format;
				%do _fmts = 1 %to 199 %by 2;
					%if %scan(&formats, &_fmts, %str( )) = &&_colname&_colnms %then %let _colfmt&_colnms = %scan(&formats, %eval(&_fmts + 1), %str( ));
					%if %scan(&formats, &_fmts, %str( )) = or &&_colfmt&_colnms ^= %then %goto breakf;
				%end;
				%breakf:;
			%end;

			* Get rtf widths: Scan the rtfwidths string to find the associated width;
			%if &rtf = YES %then %do;
				%let _colrwdth&_colnms = ;
				%do _wdths = 1 %to 199 %by 2;
					%if %scan(&rtfwidths, &_wdths, %str( )) = &&_colname&_colnms %then %let _colrwdth&_colnms = %scan(&rtfwidths, %eval(&_wdths + 1), %str( ));
					%if %scan(&rtfwidths, &_wdths, %str( )) = or &&_colrwdth&_colnms ^= %then %goto breakrw;
				%end;
				%breakrw:;
			%end;

			* Assess type: If there was an associated width then should be a PRINT variable, otherwise NOPRINT;
			%if &&_colwdth&_colnms ^= %then %let _coltype&_colnms = PRINT;
			%else %let _coltype&_colnms = NOPRINT;

			* Get the column label: Firstly check the COLWIDTH generated names and macro specified names;
			%if &&_coltype&_colnms = PRINT %then %do;
				%let _collabl&_colnms = __NOTSPEC;
				%let _coljust&_colnms = LEFT;
				%if %upcase(&&_colname&_colnms) = COL0 %then %let _collabl&_colnms = %bquote(&col0txt);
				%if %upcase(&&_colname&_colnms) = STATCOL %then %let _collabl&_colnms = %bquote(&scoltxt);
				%if &_colwrun ^= NO %then %do;
					%do _i = 1 %to &totcol;
						%if %index(&addstr, BN) %then %let _resstra = %sysfunc(tranwrd (&_resstr, %sysfunc( byte(219) ), &&&&tot&&group&_i) );
						%else %let _resstra = &_resstr;
						%if %upcase(&&_colname&_colnms) = COL&&group&_i %then %let _collabl&_colnms = %bquote(&&fullgrp&_i..&_resstra);
						%if %upcase(&&_colname&_colnms) = COL&&group&_i and %nrbquote(&coljust) = %then %let _coljust&_colnms = &justify;
					%end;
				%end;
				%if %upcase(&&_colname&_colnms) = COL&_mcol %then %do;
					%if %index(&addstr, BN) %then %let _resstra = %sysfunc(tranwrd (&_resstr, %sysfunc( byte(219) ), &&tot&_mcol) );
					%else %let _resstra = &_resstr;
					%let _collabl&_colnms = %bquote(&total.&_resstra);
					%let _coljust&_colnms = &justify;
				%end;

				* Get the column label: If not specified elsewhere get from the variable label;
			 	%if %str(&&_collabl&_colnms) = __NOTSPEC %then %do;
					proc sql noprint;
						select label into :_collabl&_colnms from dictionary.columns 
							where upcase(libname) = "&_ldsinnm" and upcase(memname) = "&_dsinnm" and upcase(name) = "%upcase(&&_colname&_colnms)";
					quit;
					%let _collabl&_colnms = %qcmpres(&&_collabl&_colnms);
				%end;
			%end;
			* Check whether the variable is ORDER or PAGE;
			%if %upcase(&&_colname&_colnms) = PAGE %then %let _incpage = Y;
			%if %upcase(&&_colname&_colnms) = ORDER %then %let _incord = Y;

			* Check whether BYVAR and BYTXT are specified;
			%if %upcase(&&_colname&_colnms) = %upcase(&byvar) and &byvar ^= %then %let _byvarinc = Y;
			%if %upcase(&&_colname&_colnms) = %upcase(&bytxt) and &bytxt ^= %then %let _bytxtinc = Y;

			* Check whether it as an ID variable;
			%let _colid&_colnms = ;
			%do _id = 1 %to 100;
				%if %scan(&idcols, &_id, %str( )) = &&_colname&_colnms %then %let _colid&_colnms = ID;
				%if %scan(&idcols, &_id, %str( )) = %then %goto breakid;
			%end;
			%breakid:;

			* Add justification, if COLJUST has a value add only to these;
			%if %nrbquote(&coljust) ^= %then %do _just = 1 %to 100;
				%if %scan(&coljust, &_just, %str( )) = &&_colname&_colnms %then %let _coljust&_colnms = &justify;
				%if %scan(&coljust, &_just, %str( )) = %then %goto breakjt;
			%end;
			%breakjt:;

			* Check whether it as a spacing variable;
			%let _colsp&_colnms = ;
			%do _sp = 1 %to 100;
				%if %scan(&spac0col, &_sp, %str( )) = &&_colname&_colnms %then %do;
					%let _colsp&_colnms = %str(spacing = 0);
					%let _totcolsp0 = %eval(&_totcolsp0 + 1);
				%end;
				%if %scan(&spac0col, &_sp, %str( )) = %then %goto breaksp;
			%end;
			%breaksp:;
		%end;

		%breakc: %let _totallc = %eval(&_colnms - 1);

		%if &byvar ^= and &_byvarinc = %then %do;
	        data _null_;
	            put "ERR" "OR: Macro parameter BYVAR is specified but variable ";
	            put "ERR" "OR: %upcase(&byvar) is not included in macro parameter COLS.";
	        run;
	        %goto here;
		%end;
		%if &bytxt ^= and &_bytxtinc = %then %do;
	        data _null_;
	            put "ERR" "OR: Macro parameter BYTXT is specified but variable ";
	            put "ERR" "OR: %upcase(&bytxt) is not included in macro parameter COLS.";
	        run;
	        %goto here;
		%end;

	%end;
	%else %do;
		%*** COLS BLANK: Create each column name, type, width, rtf width and label as macro parameters;
		* If COLS is not specified then create:
			_COLSFIN - string to go in the COLUMNS section of PROC REPORT
			_COLJUSTi - Column justification as LEFT, RIGHT or CENTER. Driven by &JUSTIFY for treatment cols, LEFT otherwise (from 1 to number of columns)
			_COLNAMEi - Column name (from 1 to number of columns)
			_COLTYPEi - Column type (print or noprint) (from 1 to number of columns)
			_COLWDTHi - Column width (from 1 to number of columns)
			_COLRWDTHi - Column rtf width (from 1 to number of columns)
			_COLLABLi - Column label (from 1 to number of columns);
		%let _colsfin = ;
		%let _colnms = 1;
		%if %nrbquote(&coljust) = %then %let _justify = &justify;
		%else %let _justify = LEFT;
		%macro coldetails(_colname, _coltype, _coljust, _colwdth, _colrwdth, _collabl);
			%global _coltype&_colnms _colname&_colnms _colwdth&_colnms _colrwdth&_colnms _collabl&_colnms _coljust&_colnms 
				_colsp&_colnms _colid&_colnms _colfmt&_colnms;
			%let _colsfin = &_colsfin &_colname;
			%let _coltype&_colnms = &_coltype;
			%let _colname&_colnms = %upcase(&_colname);
			%let _coljust&_colnms = &_coljust;
			%if &widths = %then %let _colwdth&_colnms = &_colwdth;
			%else %do;
				* Get widths: Scan the widths string to find the associated width;
				%let _colwdth&_colnms = ;
				%do _wdths = 1 %to 199 %by 2;
					%if %scan(&widths, &_wdths, %str( )) = &&_colname&_colnms %then %let _colwdth&_colnms = %scan(&widths, %eval(&_wdths + 1), %str( ));
					%if %scan(&widths, &_wdths, %str( )) = or &&_colwdth&_colnms ^= %then %goto breakw;
				%end;
				%breakw:;
			%end;

			%if &rtf = YES %then %do;
				%if &rtfwidths = %then %let _colrwdth&_colnms = &_colrwdth;
				%else %do;
					%let _colrwdth&_colnms = ;
					%do _wdths = 1 %to 199 %by 2;
						%if %scan(&rtfwidths, &_wdths, %str( )) = &&_colname&_colnms %then 
										%let _colrwdth&_colnms = %scan(&rtfwidths, %eval(&_wdths + 1), %str( ));
						%if %scan(&rtfwidths, &_wdths, %str( )) = or &&_colrwdth&_colnms ^= %then %goto breakrw;
					%end;
					%breakrw:;
				%end;
			%end;
			%let _collabl&_colnms = %bquote(&_collabl);

			* Check whether it as an ID variable;
			%let _colid&_colnms = ;
			%do _id = 1 %to 100;
				%if %scan(&idcols, &_id, %str( )) = &&_colname&_colnms %then %let _colid&_colnms = ID;
				%if %scan(&idcols, &_id, %str( )) = %then %goto breakid;
			%end;
			%breakid:;

			* Add justification, if COLJUST has a value add only to these;
			%if %nrbquote(&coljust) ^= %then %do _just = 1 %to 100;
				%if %scan(&coljust, &_just, %str( )) = &&_colname&_colnms %then %let _coljust&_colnms = &justify;
				%if %scan(&coljust, &_just, %str( )) = %then %goto breakjt;
			%end;
			%breakjt:;

			* Check whether it as a spacing variable;
			%let _colsp&_colnms = ;
			%do _sp = 1 %to 100;
				%if %scan(&spac0col, &_sp, %str( )) = &&_colname&_colnms %then %do;
					%let _colsp&_colnms = %str(spacing = 0);
					%let _totcolsp0 = %eval(&_totcolsp0 + 1);
				%end;
				%if %scan(&spac0col, &_sp, %str( )) = %then %goto breaksp;
			%end;
			%breaksp:;

			%let _colfmt&_colnms = ;
			%if %nrbquote(&formats) ^= %then %do;
				* Get formats: Scan the formats string to find the associated format;
				%do _fmts = 1 %to 199 %by 2;
					%if %scan(&formats, &_fmts, %str( )) = &&_colname&_colnms %then %let _colfmt&_colnms = %scan(&formats, %eval(&_fmts + 1), %str( ));
					%if %scan(&formats, &_fmts, %str( )) = or &&_colfmt&_colnms ^= %then %goto breakf;
				%end;
				%breakf:;
			%end;

			%let _colnms = %eval(&_colnms + 1);
		%mend;

		* BYVAR;
		%if %bquote(&byvar) ^= %then %do;
			%coldetails(&byvar , NOPRINT);
		%end;
		* BYTXT;
		%if %bquote(&bytxt) ^= %then %do;
			%coldetails(&bytxt , NOPRINT);
		%end;
		* PAGE, ORDER, COL0 and STATCOL;
		%coldetails(page , NOPRINT);
		%coldetails(order , NOPRINT);
		%coldetails(col0 , PRINT, LEFT, &w0_1, &rw0_1, %bquote(&col0txt));
		* STATCOL;
		%if %bquote(&statcol_1) = YES %then %do;
			%coldetails(statcol , PRINT, LEFT, &w1_1, &rw1_1, %bquote(&scoltxt));
		%end;
		* COL1 - COLX;
		%do _i=1 %to &totcol;
			%let _resstra = %sysfunc(tranwrd (&_resstr, %sysfunc( byte(219) ), &&&&tot&&group&_i) );
			%coldetails(col&&group&_i , PRINT, &_justify, &w1_1, &rw1_1, %bquote(&&fullgrp&_i..&_resstra));
		%end;
		* TOTAL COL;
		%if %upcase(&col10_1)=YES %then %do;
			%let _resstra = %sysfunc(tranwrd (&_resstr, %sysfunc( byte(219) ), &&tot&_mcol) );
			%coldetails(col&_mcol , PRINT, &_justify, &w1_1, &rw1_1, %bquote(&total.&_resstra));
		%end;
		%let _fcolstr = &_colsfin;
		%let _totallc = %eval(&_colnms - 1); * Total number of columns;
		%let _incpage = Y;
		%let _incord = Y;
	%end;
	%let _fprcol = 1; * Identifies the first PRINT column;
	%let _totwdth = 0; * Checks that the width of the columns adds up to LS;
	%if &rtf = YES %then %let _totrwdth = 0; * Checks that the width of the columns adds up to LS;

	%*** Save the input dataset ***;
	%if &savedsin = YES %then %do;
		%if %sysfunc(libref(&outlib)) ^= 0 %then %do; *Check the output library exists; /*** AdrianP 06DEC2023 - updated to use &outlib and amended comment ***/
	        data _null_;
	            put "ERR" "OR: Macro parameter SAVEDSIN is YES but output library is not specified. "; /*** AdrianP 06DEC2023 - updated message ***/
	            put "ERR" "OR: Either create the library or set SAVEDSIN to NO.";
	        run;
	        %goto here;
		%end;
		%else %if &sysver >= 9 %then %do; * Check the MINDEX global variable OUTNAME exists;
			%if %sysfunc(symglobl(outname)) = 0 %then %do;
		        data _null_;
		            put "ERR" "OR: Macro parameter SAVEDSIN is YES but global macro variable OUTNAME is blank.";
		            put "ERR" "OR: This should be created in (N)MINDEX macro.";
		        run;
		        %goto here;
			%end;
		%end;

		data &outlib..&outname; /*** AdrianP 06DEC2023 - updated to use &outlib ***/
			set &dsin;
			keep &_colsfin; * Keep only the variables in the PROC REPORT;
		run;
	%end;
			

	%*** Create the report **;
    proc report data=&dsin nowindows split = '|' headline headskip formchar(2)='_' spacing=1 ls=&linesize ps=&pagesize missing;

		* Specify the columns;
        columns (%if "&topline." = "YES" %then '___| '; &_fcolstr);

        %do _colnms = 1 %to &_totallc;
			%if &&_coltype&_colnms = NOPRINT %then %do;
                define &&_colname&_colnms       / order order=internal noprint &&_colid&_colnms;
            %end;
			%else %if &&_coltype&_colnms = PRINT %then %do;
                define &&_colname&_colnms / order width=&&_colwdth&_colnms "&&_collabl&_colnms" &&_coljust&_colnms flow &&_colid&_colnms  
					%if &_fprcol = 1 %then spacing = 0; %if "&rtf."="YES" %then style(column)={width=&&_colrwdth&_colnms..%}; 
						%if %nrbquote(&&_colfmt&_colnms) ^=  %then format = &&_colfmt&_colnms; &&_colsp&_colnms;
				%if &_fprcol = 1 and %nrbquote(&&_colsp&_colnms) ^= %then %let _totcolsp0 = %eval(&_totcolsp0 - 1);
				%let _fprcol = %eval(&_fprcol + 1);
				%let _totwdth = %eval(&_totwdth + 1 + &&_colwdth&_colnms);
				%if &rtf = YES %then %let _totrwdth = %eval(&_totrwdth + &&_colrwdth&_colnms);
            %end;
        %end;

		* Add page breaking and order skipping;
        %if &_incpage = Y %then break after page   / page;;
        %if &_incord = Y %then break after order  / skip;;

		* Include any additional processing specified;
		&addproc;

		* Add the BYTXT line;
        %if &byvar^= %then %do; 
            compute before _page_;
                %if &bytxt^= %then %do;
                    line @1 &bytxt $200.;
                %end;
                %else %do;
                    line @1 &byvar $200.;
                %end;
                line @1 ' ';
            endcomp;
        %end;

    run;

	* Check whether the full width is used;
	%let _twdiff = %eval(&ls + 1 - &_totwdth + &_totcolsp0);
	%if %eval(&_twdiff) < 0 and %bquote(&idcols) =  %then %do;
	    data _null_;
            put "MGCH" "ECK: Total column widths are greater than LS by %sysfunc(abs(&_twdiff))." ;
		run;
	%end;
	%else %if %eval(&_twdiff) > 0 %then %do;
	    data _null_;
            put "MGCH" "ECK: Total column widths are less than LS by &_twdiff." ;
		run;
	%end;
	%if &rtf = YES %then %do;
		%let _trwdiff = %eval(99 - &_totrwdth);
		%if %eval(&_trwdiff) < 0 and %bquote(&idcols) =  %then %do;
		    data _null_;
	            put "MGCH" "ECK: Total column RTF widths are greater than 100 by %sysfunc(abs(&_trwdiff))." ;
			run;
		%end;
		%else %if %eval(&_trwdiff) > 0 %then %do;
		    data _null_;
	            put "MGCH" "ECK: Total column RTF widths are less than 100 by &_trwdiff." ;
			run;
		%end;
	%end;

    %here:

%mend report2;
