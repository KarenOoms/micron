*****************************Quanticate*******************************;
*                                                                    *;
*  MACRO NAME       : colwidth3.sas                                  *;
*  AUTHOR           : Daniel Checketts (DC)                          *;
*                                                                    *;
*  CREATION DATE    : 22AUG2011                                      *;
*  RELEASE DATE     : 23AUG2011                                      *;
*                                                                    *;
*  LOCATION         : \\helix\data\groups\Statistics\Public\Fixed    *;
*                     Fee Department\Macros\Non-validated macros     *;
*                                                                    *;
*  ADAPTED FROM     : COLWIDTH2                                      *;
*                                                                    *;
*  PURPOSE          : Macro to create column widths and set up       *;
*                     column headers for use with report macro       *;
*                                                                    *;
* MACRO PARAMETERS  :                                                *;
*            DSIN - Input dataset containing the distinct levels of  *;
*                  GRPVAR                                            *;
*            GRPVAR - Group or treatment variable. One column will be*;
*                     created for each level of GRPVAR. Must be      *;
*                     numeric.                                       *;
*            GRPFMT - Format for GRPVAR and the text that will appear*;
*                     as the column headers                          *;
*            STATCOL - Whether there will be an extra column between *;
*                      COL0 and COL1. Usually a statistic column.    *;
*                     (YES or NO, default is NO).                    *;
*            COL10   - Whether there will be an overall column       *;
*                     (e.g. col10 or col&maxcols+1). (YES or NO,     *;
*                     default is YES).                               *;
*            LINESIZE - Line size of the proc report and the basis   *;
*                      on which the column widths will be calculated *;
*                      (Default is &ls).                             *;
*            TIDYUP	-  Whether temporary datasets created by the     *;
*                      macro should be deleted or not.               *;
*           W0 - Manual setting for COL0. Used as an alternative to  *;
*                the macro to calculate it itself.                   *;
*           W1 - Manual setting for all columns except COL0. Used as *;
*                an alternative to the macro to calculate it itself. *;
*                                                                    *;
*  OUTPUT FILES : None                                               *;
*                                                                    *;
*  ASSUMPTIONS :  To be used in conjunction with report1 macro       *;
*                                                                    *;
*  EXAMPLE MACRO CALL : %colwidth1(dsin=adsl, grpvar=trt,            *;
*          grpfmt=trtfmt., statcol=NO, col10=NO, linesize=&ls,       *;
*          w0=, w1=)                                                 *;
*                                                                    *;
*  NOTES : THIS PROGRAM MUST NOT BE ADAPTED FOR STUDY SPECIFIC       *;
*          ANALYSES. ANY CHANGES OR UPDATES REQUIRED MUST BE         *;
*          BE IDENTIFIED IN THE MACRO UPDATE LOG. ANY UPDATES MUST   *;
*          BE VALIDATED AS DEFINED IN 'SAS MACRO LIFE-CYCLE' SOP     *;
*          SOP PRG-SOP-005.                                          *;
*          THIS PROGRAM AND ASSOCIATED DATASETS SHOULD NOT BE        *;
*          PASSED ONTO ANY THIRD PARTIES EXCEPT REGULATORY           *;
*          AUTHORITIES.                                              *;
*                                                                    *;
*  NOTE: FURTHER INFORMATION ON THE SAS MACRO CAN BE FOUND IN        *;
*        THE MACRO SPECIFICATION DOCUMENT CONTAINED IN               *;
*Q:\Central Project Resources\Generic Macros\Specification Documents *;
*                                                                    *;
*  CHANGE HISTORY  (ENSURE THAT ANY UPDATES ARE REFERENCED IN THE    *;
*                  PROGRAM WITH PROGRAMMER INITIALS AND DATE)        *;
*                                                                    *;
*  USERID   | DATE       | CHANGE                                    *;
* ----------+------------+-------------------------------------------*;
* williamp  | 14MAR2016  | Replace WA-RNINGS with MGCH-ECK instead   *;
*           |            | Some additional checks of widths have been*;
*           |            | added                                     *;
* williamp  | 12MAY2016  | Minor wording amendments to checks        *;
* williamp  | 17MAY2016  | Updates to header                         *;
*	SA		| 03MAY2018  | Commented out the "%nrquote" part.		 *;
**********************************************************************;

%macro colwidth3(dsin       =
                 , grpvar   =
                 , grpfmt   =
                 , statcol  = NO
                 , col10    = YES
                 , linesize = &ls
                 , w0       =
                 , w1       =
                 , tidyup   = YES
                );

    %******************************; 
    %*** Detail local variables ***;
    %******************************;
    %local _vartype ;

    %*******************************************; 
    %*** Detail global macro variables       ***;
    %*******************************************;
    %global w0_1 w1_1 col10_1 statcol_1 totcol;

    %let w0_1      = &w0;
    %let w1_1      = &w1;
    %let col10_1   = %upcase(&col10);
    %let statcol_1 = %upcase(&statcol);
    %let tidyup    = %upcase(&tidyup);

    %if       %index(&statcol_1,Y) %then %let statcol_1 = YES ;
    %else %if %index(&statcol_1,N) %then %let statcol_1 = NO ;
    %if       %index(&col10_1,Y)   %then %let col10_1   = YES ;
    %else %if %index(&col10_1,N)   %then %let col10_1   = NO ;
    %if       %index(&tidyup,Y)    %then %let tidyup    = YES ;
    %else %if %index(&tidyup,N)    %then %let tidyup    = NO ;

    %*** macro parameter checking ***;
    %if %bquote(&dsin)= %then %do;
        data _null_;
            put "ERR" "OR: Macro parameter DSIN has " "not been specified.";
        run;
        %goto here;
    %end;
	%let _dsetin = %scan(%bquote(&dsin), 1, %str(%());
    %if %sysfunc(exist(&_dsetin))=0 %then %do;
        data _null_;
            put "ERR" "OR: Dataset &dsin does not exist.";
        run;
        %goto here;
    %end;
    %if &grpvar= %then %do;
        data _null_;
            put "ERR" "OR: Macro parameter GRPVAR has " "not been specified.";
        run;
        %goto here;
    %end;
    %if &grpfmt= %then %do;
        data _null_;
            put "ERR" "OR: Macro parameter GRPFMT has " "not been specified.";
        run;
        %goto here;
    %end;
    %if &linesize= %then %do;
        data _null_;
            put "ERR" "OR: Macro parameter LINESIZE has " "not been specified.";
        run;
        %goto here;
    %end;

    %******************************************************************************************;
    %*** determine whether &grpvar exists in dataset and then if it is character or numeric ***;
    %******************************************************************************************;
    data _null_;
        format type $3. ; 
        dsid=open("&dsin",'i');
        vnum=varnum(dsid,"&grpvar");
		if vnum=0 then call symput('_vartype', '0');
		else do;
	        type=vartype(dsid,vnum);
	        rc=close(dsid); 
	        call symput('_vartype', type);
		end;
    run;

    %if &_vartype = 0 %then %do;
        data _null_;
            put "ERR" "OR: Macro parameter GRPVAR: (&grpvar) " "does not exist within dataset &dsin..";
        run;
        %goto here;
    %end;    
    %else %if &_vartype = C %then %do ;
        data _null_;
            put "ERR" "OR: Macro parameter GRPVAR: (&grpvar) is character " 
                "but it MUST be numeric."
            ;
        run;
        %goto here;
    %end;

    %*** Specify macro variables ***;
    data _mpl_;
        set &dsin;
        _fullgrp=put(&grpvar,&grpfmt);
        format &grpvar best.;
    run;

    %*** Count the number of distinct values of grpvar ***;
    proc sql noprint;
        select count(distinct &grpvar)
        into:  totcol
        from   _mpl_ where &grpvar ^= .;
        ;
    quit;
    %let totcol=&totcol;

    %if &totcol>0 %then %do;
        %do _i=1 %to &totcol;
            /*%nrquote*/%global group&_i. fullgrp&_i.; /*SA03MAY2018: Commented out the "%nrquote" part*/
        %end;
    
        proc sql noprint;
            select distinct &grpvar
                            , _fullgrp
            into            :group1 - :group&totcol
                            ,:fullgrp1 - :fullgrp&totcol
            from            _mpl_ where &grpvar ^= .
            order by        &grpvar
            ;
        quit;

        %*** Formula to calculate the column widths for different numbers of groups ***;
        data work._colwidth ;
            col10="&col10_1";
            statcol="&statcol_1";
            totcol=%eval(&totcol);
            ls=%eval(&linesize);
            if      col10='YES' and statcol='YES' then totcol1=totcol+2;
            else if col10='YES' or  statcol='YES' then totcol1=totcol+1;
            else                                       totcol1=totcol;
            
            %*** automatic calculation of w0 and w1 ***;
            %if &w0= and &w1= %then %do;
                if ls<=100 then do;
                    if      totcol1<=3 then w1=21;
                    else if totcol1 =4 then w1=16;
                    else if totcol1 =5 then w1=12;
                    else if totcol1 =6 then w1=10;
                    else if totcol1 =7 then w1=9;
                    else if totcol1 >7 then w1=8;
                end;
                else if 100<ls<=120 then do;
                    if      totcol1<=3 then w1=23;
                    else if totcol1 =4 then w1=19;
                    else if totcol1 =5 then w1=16;
                    else if totcol1 =6 then w1=13;
                    else if totcol1 =7 then w1=11;
                    else if totcol1 >7 then w1=9;
                end;
                else if ls>120 then do;
                    if      totcol1<=3 then w1=27;
                    else if totcol1 =4 then w1=23;
                    else if totcol1 =5 then w1=18;
                    else if totcol1 =6 then w1=15;
                    else if totcol1 =7 then w1=13;
                    else if totcol1 =8 then w1=11;
                    else if totcol1 =9 then w1=10;
                    else if totcol1 >9 then w1=9;
                end;

                w0 = ls - (w1*totcol1) - totcol1; %*** assumes that spacing=0 for col0 and spacing=1 otherwise ***;
                if w0<10 then do;
                    put "MGCH" "ECK: The automatic width set for COL0 based" 
                        " on the line size " ls "is " w0 "which may be too little."
                    ;
                end;
            %end;
            %else %if &w0^= and &w1= %then %do;
                w0=%eval(&w0);
                w1 = floor((ls - w0 - totcol1)/totcol1);
                remainder=ls - (w1*totcol1) - totcol1 - w0;
                if remainder>0 then do;
                    w0=w0+remainder;
                    put "NOTE: To fit the line size " 
                        ls "a width of " remainder "was added to the specified w0."
                    ;
                end;
                if w0<10 then do;
                    put "MGCH" "ECK: The chosen width of " w0 "(re-calculated) specified for COL0 may be too little.";
                end;
                if w1<7 then do;
                    put "MGCH" "ECK: The chosen width set for COL0 column" 
                        " has resulted in a width for all columns of " w1 "that may be too little." ;
                end;
            %end;
            %else %if &w0= and &w1^= %then %do;
                w1=%eval(&w1);
                w0 = ls - (w1*totcol1) - totcol1; %*** assumes that spacing=0 for col0 and spacing=1 otherwise ***;
                if w0<10 then do;
                    put "MGCH" "ECK: The chosen width set for all columns" 
                        " has resulted in a width for COL0 of " w0 "that may be too little." ;
                end;
                if w1<7 then do;
                    put "MGCH" "ECK: The chosen width of " w1 "specified for COL1-COLX may be too little.";
                end;
            %end;
            %else %if &w0^= and &w1^= %then %do;
                w0=%eval(&w0);
                w1=%eval(&w1);
                ls1= w0 + (w1*totcol1) + totcol1;
                if ls1>ls then do;
					diff = ls1 - ls;
                    put "MGCH" "ECK: The line size " ls 
                        "is too little for the input values of w0 and w1.  The total calculated widths are " diff "too high.";
                end;
                if ls1<ls then do;
					diff = ls - ls1;
                    put "MGCH" "ECK: The linesize of " ls "is not filled by the specified input values of w0 and w1.  " 
                        "There is additional space of " diff "remaining.";  
                    ;
                end;
 	            if w1<7 then do;
                    put "MGCH" "ECK: The chosen width of " w1 "specified for COL1-COLX may be too little.";
	            end;
	            if w0<10 then do;
                    put "MGCH" "ECK: The chosen width of " w0 "(re-calculated) specified for COL0 may be too little.";
	            end;
           %end;
            call symput('w0_1',trim(left(put(w0,best.))));
            call symput('w1_1',trim(left(put(w1,best.))));
        run;

    %end;

    %else %do;
        data _null_;
            put "ERR" "OR: There are no distinct levels of &grpvar in dataset &dsin..";
        run;
    %end;

    %*************************************************************;
    %*** If requested delete datasets created by PAGENUM macro ***;
    %*************************************************************;
    %if &tidyup = YES %then %do;
	    proc datasets lib = work nolist nodetails memtype = data;
            delete 
                  %if %sysfunc(exist(work._mpl_))=1 %then _mpl_;
                  %if %sysfunc(exist(work._colwidth))=1 %then _colwidth;;
	    run;
        quit;
    %end;

    %here:

%mend colwidth3;
