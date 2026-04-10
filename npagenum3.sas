*****************************Quanticate******************************;
*                                                                   *;
*  MACRO NAME       : npagenum3.sas                                 *;
*  AUTHOR           : Will Paget (WP)                               *;
*                                                                   *;
*  CREATION DATE    : 24MAR2015                                     *;
*  RELEASE DATE     : 08SEP2016                                     *;
*                                                                   *;
*  LOCATION         : Q:\Central Project Resources\Generic Macros   *;
*                     \Validated Macros                             *;
*                                                                   *;
*  ADAPTED FROM     : npagenum2.sas                                 *;
*                                                                   *;
*  PURPOSE          : To add 'Page X of Y', and 'continued' lines   *;
*                     to an already existing table according to     *;
*                     Client 024 standards                          *;
*                                                                   *;
*  MACRO PARAMETERS :                                               *;
*  input    - name of input filename (default is                    *;
*             "&outdir.\&outfile.")                                 *;
*  output   - name of output filename (default is                   *;
*             "&outdir.\&outfile.")                                 *;
*  pagenum1 - String which will identify where a new page starts.   *;
*             This needs to be what is on the first line on any     *;
*             page. (default is &STUDYID.)                          *;
*  pagenum2 - string which will identify unique tables (default is  *;
*             &TABNO.)                                              *;
*  pagenum3 - String which will identify line on which 'Page X of   *;
*             Y' is to go (default is 'Table')                     *;
*  unwanted - String used to exclude source data line from          *;
*             attachment of 'Page X of Y' is to go (default is      *;
*             'Source Data:')                                       *;
*  cont1    - String which will identify continued title (default   *;
*             is (continued)) [PAGENUM replaces this string         *;
*             with blanks if it is the first title]                 *;
*  cont2    - String to add to end of page when table is continued  *;
*             (default is (continued on next page))                 *;
*             [PAGENUM replaces the string 'LAST LINE' with this    *;
*             text,if 'LAST LINE' is not present PAGENUM does       *;
*             nothing]                                              *;
*  linesize - Line size to be used (default is &ls)                 *;
*  replace  - Denote whether to replace text of PAGENUM3 with       *;
*             blanks or not YES/NO (default is NO)                  *;
*  tidyup   - denote whether to delete datasets created by PAGENUM  *;
*             or not YES/NO (default is YES but would be useful to  *;
*             change if trying to determine why unexpected results  *;
*             determine why unexpected results occur)               *;
*                                                                   *;
*  OUTPUT FILES : Depends on the macro call (default is             *;
*                 &outdir.\&outfile.)                               *;
*                                                                   *;
*  ASSUMPTIONS : PAGENUM cannot handle different sizes of page      *;
*                within the same file (since it uses &ls to         *;
*                determine page sizes).                             *;
*                PAGENUM will not work on files that already have   *;
*                Page X of Y on them.                               *;
*                                                                   *;
*  EXAMPLE MACRO CALL : %npagenum3(input=table, output=table,       *;
*                       pagenum1=Protocol:, pagenum2=Table,         *;
*                       pagenum3=Protocol:, cont1=(continued),      *;
*                       cont2 = (continued on next page),           *;
*                       replace=NO, tidyup=YES)                     *;
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
* WP        | 25AUG2016  | Added drop statements to _TITLES4 to     *;
*           |            | avoid 'over-written' appearing in the    *;
*           |            | log, created as Version 3                *;
*           |            | Updated the default for PAGENUM3 to TABLE*;
*           |            | Outputted the LOG and LST file to ensure *;
*           |            | NPAGENUM still appears in the log        *;
*           |            | Removed RTF as this did not work and was *;
*           |            | not being used                           *;
*           | 08SEP2016  | Update for pages >10000                  *;
*********************************************************************;

%macro npagenum3(input      = "&outdir.\&outfile."
				 , output   = "&outdir.\&outfile."
				 , pagenum1 = &studyid.
				 , pagenum2 = &tabno.
				 , pagenum3 = Table
				 , unwanted = Source Data:
				 , cont1    = (continued)
				 , cont2    = (continued on next page)
				 , linesize = &ls
				 , replace  = NO
				 , tidyup   = YES
			   );

	%*******************************************;
	%*** Declare local macro variables       ***;
	%*******************************************;
	%local _dsid _rc _any _stopp _output _lstlog;

    %if &sysver >= 9 %then %do;
		%if %sysfunc(symglobl(logdir)) ^= 0 and %sysfunc(symglobl(logfile)) ^= 0 and 
			%sysfunc(symglobl(outdir)) ^= 0 and %sysfunc(symglobl(lstfile)) ^= 0 %then %do;
				%if %bquote(&logdir) ^= and %bquote(&logfile) ^= and %bquote(&outdir) ^= and %bquote(&lstfile) ^= %then %do;
					%let _lstlog = Y; * Specifies that the LOG and LST files are being output;
					proc printto
						log  ="&logdir.\&logfile"
						print="&outdir.\&lstfile";
					run;
				%end;
		%end;
	%end;

    %*** Check that macro parameters are valid *** ;
    %pcheckyn1(param = replace);
	%if &_skip = 1 %then %goto _quit;
    %pcheckyn1(param = tidyup);
	%if &_skip = 1 %then %goto _quit;

	* Check INPUT;
	%if %nrbquote(&input) =  %then %do;
			%put %str(ER)%str(ROR: Macro parameter INPUT is blank.);
		%goto _quit;
	%end;
	%if %nrbquote(&input) = %then %do;
		%put %str(ER)%str(ROR: Macro parameter INPUT must be assigned a value.);
		%goto _quit;
	%end;
	%if %sysfunc(fileexist(&input)) = 0 and %sysfunc(fileref(&input)) ^= 0 %then %do;
		%put %str(ER)%str(ROR: %upcase(&INPUT) is not a file reference or a valid file path);
		%goto _quit;
	%end;

	* Check OUTPUT;
	%if %nrbquote(&output) =  %then %do;
			%put %str(ER)%str(ROR: Macro parameter OUTPUT is blank.);
		%goto _quit;
	%end;
	%let _output = %sysfunc( tranwrd(%bquote(&output), %str(%"), %str()) );
	%let _output = %sysfunc( tranwrd(%bquote(&_output), %str(%'), %str()) );
	%let _output = %sysfunc( tranwrd(%bquote(&_output), %str(/), %str(\)) );
	%if %index(&_output, \) %then %let _output = %substr(&_output, 1, %eval(%length(&_output) - %index( %sysfunc( reverse(&_output) ) , \) ) );
	%if %sysfunc(fileexist(&_output)) = 0 and %sysfunc(fileref(&output)) > 0 %then %do;
		%put %str(ER)%str(ROR: %upcase(&OUTPUT) is not a file reference or the file path referenced in %upcase(&OUTPUT) does not exist);
		%goto _quit;
	%end;

	* Check LINESIZE;
	%if &linesize ^= %then %do;
		%if %sysfunc(anyalpha(&linesize)) ^= 0 %then %do;
			%put %str(ER)%str(ROR: Macro parameter LINESIZE must be a positive number.);
			%goto _quit;
		%end;
		%if %eval(&linesize) le 0 %then %do;
			%put %str(ER)%str(ROR: Macro parameter LINESIZE must be a positive number.);
			%goto _quit;
		%end;
	%end;
	%else %do;
		%put %str(ER)%str(ROR: Macro parameter LINESIZE must be a positive number.);
		%goto _quit;
	%end;

	* Check PAGENUM/CONT/UNWANTED parameters;
	%if %nrbquote(&pagenum1) = %then %do;
		%put %str(ER)%str(ROR: Macro parameter PAGENUM1 must be assigned a value.);
		%goto _quit;
	%end;
	%if %nrbquote(&pagenum2) = %then %do;
		%put %str(ER)%str(ROR: Macro parameter PAGENUM2 must be assigned a value.);
		%goto _quit;
	%end;
	%if %nrbquote(&unwanted) = %then %do;
		%put %str(ER)%str(ROR: Macro parameter UNWANTED must be assigned a value.);
		%goto _quit;
	%end;
	%if %nrbquote(&pagenum3) = %then %do;
		%put %str(ER)%str(ROR: Macro parameter PAGENUM3 must be assigned a value.);
		%goto _quit;
	%end;
	%if %nrbquote(&cont1) = %then %do;
		%put %str(ER)%str(ROR: Macro parameter CONT1 must be assigned a value.);
		%goto _quit;
	%end;
	%if %nrbquote(&cont2) = %then %do;
		%put %str(ER)%str(ROR: Macro parameter CONT2 must be assigned a value.);
		%goto _quit;
	%end;

	%*******************************************************************************************;
	%*** Read in data from &input file, create ordering variable _i to identify each of the  ***;
	%*** different pages of the table - based on the assumption that the each new page will  ***;
	%*** start with the string contained in macro variable PAGENUM1                          ***;
	%*** Where PAGENUM1 is blank, then the form feed (or page break) character is used.      ***;
	%*******************************************************************************************;
	data work._output;
		length _line $ 200;
		infile &input truncover end=last;
		input _line $char200.;
	%if "&pagenum1." ne "" %then %do;
		if index(_line, "&pagenum1") ne 0 then _i+1;
	%end;
	%else %do;
		if _n_=1 then _i=1;
		if index(_line, byte(12)) ne 0 then _i+1;
	%end;
	run;

	%*** Killing macro when value of PAGENUM contains an incorrect study code ***;
	proc sql noprint;
		select max(_i) into :_max_i 
			from work._output;
	quit;

	%if &_max_i=0 %then %do;
		data _null_;
			put "ER" "ROR: The value of macro parameter PAGENUM1" " does not match " 
				"what is at the start of the first line of any page in the output.";
			put "INFO: Please check that the right study code is being used.";
		run;
		%goto _quit;
	%end;

	%************************************************************************************************;
	%*** Step to check whether the output dataset is empty (i.e. if the table file was completely ***;
	%*** blank) and to run the page numbering part only if the dataset exists                     ***;
	%************************************************************************************************;
	%let _dsid = %sysfunc(open(_output));
	%let _any  = %sysfunc(attrn(&_dsid,any));
	%let _rc   = %sysfunc(close(&_dsid));

	%if (&_any = 1) %then %do;

		%*******************************************************************************************;
		%*** select just the lines from the table that identify the tables - based on assumption ***;
		%*** that the table number will do this and will be on a line beginning with the string  ***;
		%*** contained in macro variable PAGENUM2                                                ***;
		%*******************************************************************************************;
		data work._titles;
			set work._output;
			where index(_line, "&pagenum2") ne 0;
		run;

		%***************************************************************************************;
		%*** create ordering variable _j to determine how many different tables in the file  ***;
		%*** and page number variable PAGES to give the page number within each unique table ***;
		%***************************************************************************************;
		data work._titles2 ;
			length _lastl $ 200;
			set work._titles;
			retain _pages;

			_lastl = lag(_line);

			if _line ne _lastl then do;
				_pages=1;
				_j+1;
			end;
			else _pages=_pages+1;
		run;

		%*******************************************************;
		%*** create page number variable _pages2 to give     ***;
		%*** the total number of pages for each unique table ***;
		********************************************************;
		data work._titles3 (drop= _i _pages);
			set work._titles2;
			by _j;
			_pages2= _pages;
			if last._j;
		run;

		%*********************************************************;
		%*** merge _titles2 and _titles3 to create one dataset ***;
		%*** with the variables _i, _pages and _pages2         ***;                                                            ***;
		%*********************************************************;
		data work._titles4(keep = _i _pages _pages2);
			 merge work._titles2 (drop = _lastl _line)
				   work._titles3 (drop = _lastl _line)
			 ;
			 by _j;
		run;

		proc sort data = _titles4 nodupkey;
			by _i _pages _pages2;
		run;

		%***************************************************************************************;
		%*** Merge titles back with output and add some words to the first line of each table***;
		%*** to fill in the page numbers based on _pages and _pages2.                        ***;
		%*** Also removed the text &CONT1 from the title on the first page if it exists and  ***;
		%*** add the text &CONT2 to all pages except the last                                ***;
		%***************************************************************************************;
		data _null_;
			length pagebit $ 10 z2 $ 100;
			retain z1 ;
			file &output;
			merge work._output
				   work._titles4
			;
			by _i;
			if index(_line, "&pagenum3") ne 0 then do;
				if index(_line, "&unwanted.")=0 then z1 = index(_line, "&pagenum3") ;
				if z1 = 1 then z2 = ' ' ;
				else if index(_line, "&unwanted.")=0 then z2 = substr(_line, 1,(z1-1));
				if _pages < 10 then pagebit = 'Page ' || put(_pages, 1.);
				else if _pages < 100 then pagebit = 'Page ' || put(_pages, 2.);
				else if _pages < 1000 then pagebit = 'Page ' || put(_pages, 3.);
				else if _pages < 10000 then pagebit = 'Page ' || put(_pages, 4.);
				else pagebit = 'Page ' || put(_pages, 5.);
			%*** Length of Page X of Y for use in recentring title line ***;
				l_pagebit=length(pagebit)+6+length(strip(put(_pages2,best.)));

				if index(_line, "&unwanted.")=0 then do;

			%*** Either put 'Page X of Y'  at end of line after pagenum3 or replace pagenum3 with blanks ***;
					if "&replace" = 'NO' then do;
						n=1;
						if substr(_line,1,1) eq " " then _line=trim(substr(_line,int(l_pagebit/2))) || repeat(' ',n) || "(" || trim(pagebit);
						else _line=trim(_line) || repeat(' ',n) || "(" || trim(pagebit);
					end;
					else if "&replace" = 'YES' then do;
						if _pages2 ge 10000 then do;
							if _N_=1 then n=&linesize-length(trim(z2))-length(trim(pagebit))-10;
							else n=&linesize-length(trim(z2))-length(trim(pagebit))-9;
						end;
						else if _pages2 ge 1000 then do;
							if _N_=1 then n=&linesize-length(trim(z2))-length(trim(pagebit))-9;
							else n=&linesize-length(trim(z2))-length(trim(pagebit))-8;
						end;
						else do;
							if _N_=1 then n=&linesize-length(trim(z2))-length(trim(pagebit))-8;
							else n=&linesize-length(trim(z2))-length(trim(pagebit))-7;
						end;
						_line=trim(z2)||repeat(' ',n)||trim(pagebit);
					end;
					total=put(_pages2,5.);
			%*** Adding total number of pages to string ***;
					_line=trim(_line)||" of "||compress(total);
			%*** Adding final bracket where original string is not replaced ***;
					if "&replace"='NO' then do;
						_line=trim(_line) || ")";
					end;
				end;
			end;

			%let _fmt=$char200.;
			%*** Continued text removed from page 1 of file ***;
			if index(_line, "&CONT1") ne 0 then do;
				if _pages = 1 then do;
					words = tranwrd(_line, "&CONT1","");
					put @1 words &_fmt.;
				end;
				else put _line &_fmt.;
			end;
			else if index(_line, "LAST LINE") ne 0 then do;
			%*** Using value of CONT2 for non-final pages of multi-page file,  ***;
			%*** otherwise set to missing for one page file or delete for last ***;
			%*** page of multi-page file                                       ***;
				if _pages ne _pages2 then _line = "&CONT2";
				else if _pages2=1 then _line="";
				else if _pages=_pages2 then delete;
				put _line &_fmt.;
			end;
			%*** If none of the above then output as is ***;
			else put _line &_fmt.;

		run;

   %end;

   %*************************************************************;
   %*** If requested delete datasets created by PAGENUM macro ***;
   %*************************************************************;
   %if &tidyup = YES %then %do;
		proc datasets lib = work nolist nodetails memtype = data;
			delete _output _titles: ;
		run;
		quit;
   %end;

   %_quit:

	* If the LOG and LST files were output at the start of the macro now close them again;
    %if &_lstlog = Y %then %do;
		proc printto;
		run;
	%end;

%mend npagenum3;
