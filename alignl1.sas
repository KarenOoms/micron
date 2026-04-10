*****************************Quanticate******************************;
*                                                                   *;
*  MACRO NAME       : alignl1.sas                                   *;
*  AUTHOR           : William Paget (WP)                            *;
*                                                                   *;
*  CREATION DATE    : 02MAR2016                                     *;
*  RELEASE DATE     : 30MAR2016                                     *;
*                                                                   *;
*  LOCATION         : \\helix\data\groups\Statistics\Public\Fixed   *;
*                     Fee Department\Macros\Non-validated macros    *;
*                                                                   *;
*  ADAPTED FROM     :                                               *;
*                                                                   *;
*  PURPOSE          : Remove leading blanks from columns whilst     *;
*                     maintaining the alignment                     *;
*                     Is applied to COL1 - COLX                     *;
*                                                                   *;
*  MACRO PARAMETERS :                                               *;
*   DSIN      - The name of the dataset containing the data to be   *;
*               formatted                                           *;
*   OUT       - The name of the output dataset                      *;
*   ALIGNALL  - If YES the indent to use for the alignment is       *;
*               kept consistent across all columns.  If NO each     *;
*               column is aligned separately                        *;
*   INDENTF   - Adds further leading blanks                         *;
*   TIDYUP    - denote whether to delete datasets created           *;
*               by ALIGNL or not YES/NO (default is YES             *;
*               but would be useful to change if trying to          *;
*               determine why unexpected results occur)             *;
*                                                                   *;
*  ASSUMPTIONS  : The dataset must contain COL1 - COLX              *;
*                                                                   *;   
*  EXAMPLE MACRO CALL :  %alignl(in=out1, out=out2, ALIGNALL=Y);    *; 
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
*       	|          	 | 											*;
*********************************************************************;
*                                                                   *;
*  Result     - Dataset called &OUT containing identical variables  *;
*               to the input dataset but with alignment applied     *;
*********************************************************************;

%macro alignl1(dsin          =
               , out       =
               , alignall  = NO
               , indentf   = 0
               , tidyup    = YES
              );

    %*******************************************; 
    %*** Detail local macro variables        ***;
    %*******************************************;
    %local _ldsinnm _dsinnm _tcols;

    %let tidyup  = %upcase(&tidyup);
    %if       %index(&tidyup,Y)  %then %let tidyup  = YES ;
    %else %if %index(&tidyup,N)  %then %let tidyup  = NO ;

    %let alignall  = %upcase(&alignall);
    %if       %index(&alignall,Y)  %then %let alignall  = YES ;
    %else %if %index(&alignall,N)  %then %let alignall  = NO ;

    %*******************************************;
    %*** Checking the the dataset exists and ***;
    %*** contains the correctly defined      ***;
    %*** parameters                          ***;
    %*******************************************;

    %if &out= %then %do;
        data _null_;
          put "ERR" "OR: An output dataset must be specified";
        run;
        %goto here;
    %end;
    %if %nrbquote(&dsin)= %then %do;
        data _null_;
          put "ERR" "OR: An input dataset must be specified";
        run;
        %goto here;
    %end;
    %if &alignall ^= YES and &alignall ^= NO %then %do;
        data _null_;
          put "ERR" "OR: Macro parameter ALIGNALL must take values of YES or NO";
        run;
        %goto here;
    %end;
    %if &indentf =  %then %do;
        data _null_;
          put "ERR" "OR: Macro parameter INDENTF is missing";
        run;
        %goto here;
    %end;
    %if %sysfunc(anyalpha(&indentf)) ^= 0 or %sysfunc(anydigit(&indentf)) = 0 %then %do;
        data _null_;
          put "ERR" "OR: Macro parameter INDENTF must be a number greater than or equal to 0";
        run;
        %goto here;
    %end;
	%else %if &indentf lt 0 %then %do;
        data _null_;
          put "ERR" "OR: Macro parameter INDENTF must be a number greater than or equal to 0";
        run;
        %goto here;
    %end;
    %if &tidyup ^= YES and &tidyup ^= NO %then %do;
        data _null_;
          put "ERR" "OR: Macro parameter TIDYUP must take values of YES or NO";
        run;
        %goto here;
    %end;

	* Check whether the input dataset is from the work library;
	%let _dsinnm = %scan(&dsin, 1, %() );
	%if %index(&_dsinnm, .) %then %do;
		%let _ldsinnm = %upcase( %scan(&_dsinnm, 1, .) );
		%let _dsinnm = %upcase( %scan(&_dsinnm, 2, .) );
	%end;
	%else %do;
		%let _ldsinnm = WORK;
		%let _dsinnm = %upcase(&_dsinnm);
	%end;

	* Check that the input dataset exists;
	%if %sysfunc(exist(&_ldsinnm..&_dsinnm))=0 %then %do;
        data _null_;
            put "ERR" "OR: Dataset &dsin does not exist.";
        run;
        %goto here;
    %end;

	* Create every character COLX (where X is a number) as a macro parameter;
	proc sql noprint;
		select name into :_colnm1 - :_colnm1000 from dictionary.columns where upcase(libname) = "&_ldsinnm" and upcase(memname) = "&_dsinnm" and 
			type = 'char' and substr( upcase(name), 1, 3) = "COL" and anyalpha( substr( upcase(name), 4) ) = 0 and upcase(name) not in ('COL' 'COL0');
	quit;
	%let _tcols = &sqlobs;

	%if &_tcols = 0 %then %do;
        data _null_;
            put "ERR" "OR: There are no valid columns in dataset &dsin";
            put "ERR" "OR: (character columns named COLX, where X is a number).";
	        put "ERR" "OR: The ALIGNL macro is designed to be used with output datasets from the standard Quanticate";
        run;
        %goto here;
    %end;

	%*** Check the leading blanks in each column;
	data _dset;
		set &dsin (keep = %do _col = 1 %to &_tcols; &&_colnm&_col %end;);
		%do _col = 1 %to &_tcols;
			if &&_colnm&_col ^= '' then _indent&_col = length(&&_colnm&_col) - length( strip(&&_colnm&_col) );
		%end;
		drop col:;
	run;

	%*** Work out minimum ***;
	%do _col = 1 %to &_tcols;
		proc sql noprint;
			select distinct min(_indent&_col) + 1 into :_substr&_col from _dset;
		quit;
		%if &&_substr&_col = %then %let _substr&_col = 200; * Set arbitrarily high;
	%end;

	%*** Get the overall minimum if ALIGNALL is YES ***;
	%if &alignall = YES %then %do;
		%local _colmin;
		%let _colmin = &_substr1;
		%do _col = 2 %to &_tcols;
			%if &&_substr&_col < &_colmin %then %let _colmin = &&_substr&_col;
		%end;
		%do _col = 1 %to &_tcols;
			%let _substr&_col = &_colmin;
		%end;
	%end;

	%do _col = 1 %to &_tcols;
		%if &&_substr&_col = %then %let _substr&_col = 1;
	%end;

	%*** Apply the alignment ***;
	data &out;
		set &dsin;
		%do _col = 1 %to &_tcols;
			if length(&&_colnm&_col) ge &&_substr&_col then &&_colnm&_col = %if &indentf eq 1 %then ' ' || ;
				 %if &indentf gt 1 %then repeat(' ', %eval(&indentf - 1)) ||; substr(&&_colnm&_col, &&_substr&_col);
			else &&_colnm&_col = %if &indentf eq 1 %then ' ' || ; %if &indentf gt 1 %then repeat(' ', %eval(&indentf - 1)) ||; &&_colnm&_col;
		%end;
	run;

    %*** Tidy up output dataset ***;
    %if &tidyup = YES %then %do;
        proc datasets lib=work nolist nodetails memtype=data;
            delete _dset;
        run;
        quit;
    %end;

    %here:; %*** Comes here if there are er-rors ***;

%mend alignl1;
