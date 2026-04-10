********************************Quanticate**********************************;
*                                                                          *;
*  MACRO NAME       : pagenum4.sas                                         *;
*  AUTHOR           : Will Paget (WP)                                      *;
*                                                                          *;
*  CREATION DATE    : 21JAN2010                                            *;
*  RELEASE DATE     : 16AUG2024                                            *;
*                                                                          *;
*  LOCATION          : Q:\Central Project Resources\Generic Macros\        *;
*                      Validated Macros\                                   *;
*                                                                          *;
*  ADAPTED FROM      : pagenum3.sas.                                       *;
*                                                                          *;
*  PURPOSE           : Add 'Page X of Y' and '(continued on next page)'    *;
*                      lines to a pre-existing table.                      *;
*                                                                          *;
*  MACRO PARAMETERS  :                                                     *;
*  INPUT    - Optional. The source file to add the page numbering to. The  *;
*             default value is "&OUTDIR\&OUTFILE".                         *;
*  OUTPUT   - Optional. The resulting file with page numbering added, if   *;
*             the same as INPUT then the source file will be overwritten.  *;
*             The default value is &INPUT.                                 *;
*  PAGENUM1 - Optional. The string which identifies the start of a new     *;
*             page. The default value is 'Protocol:'.                      *;
*  PAGENUM2 - Optional. A string which is unique to each table in the file *;
*             and occurs exactly once per page. The line containing this   *;
*             string must be identical for every page of the table. The    *;
*             default value is &TABNO.                                     *;
*  PAGENUM3 - Optional. The string which identifies the line to add 'Page  *;
*             X of Y' to. The default value is &PAGENUM1.                  *;
*  CONT1    - Optional. The string which identifies the automatic          *;
*             continued title, any line containing this string on page 1   *;
*             of the table will be truncated immediately before it. The    *;
*             default value is '(continued)'.                              *;
*  CONT2    - Optional. The string which will replace 'LAST LINE' on all   *;
*             pages except the last page, where 'LAST LINE' will be        *;
*             replaced with blanks. The default value is '(continued on    *;
*             next page)'.                                                 *;
*  LINESIZE - Optional. The line size of the table, used to correctly      *;
*             position 'Page X of Y' and &CONT2. The default value is &LS. *;
*  REPLACE  - Optional. Specifies whether to truncate any line containing  *;
*             &PAGENUM3 to remove it, prior to adding 'Page X of Y'. The   *;
*             default value is NO.                                         *;
*  TIDYUP   - Optional. Specifies whether to delete temporary datasets     *;
*             created by the macro. The default value is YES.              *;
*                                                                          *;
*  OUTPUT FILES : The file specified in OUTPUT. This macro also resumes    *;
*                 the LOG and LST files defined by MINDEX4.                *;
*                                                                          *;
*  ASSUMPTIONS : Every page of the input file must be the same size,       *;
*                which must be specified in the LINESIZE parameter.        *;
*                'Page  X of Y' must not be already present.               *;
*                Options NONUMBER and NODATE must have been used when      *;
*                creating the input file.                                  *;
*                                                                          *;
*  EXAMPLE MACRO CALL :                                                    *;
*    %pagenum4(input    = "&outdir\&outfile"                               *;
*             ,output   = &input                                           *;
*             ,pagenum1 = 'Protocol:'                                      *;
*             ,pagenum2 = &tabno                                           *;
*             ,pagenum3 = &pagenum1                                        *;
*             ,cont1    = '(continued)'                                    *;
*             ,cont2    = '(continued on next page)'                       *;
*             ,linesize = &ls                                              *;
*             ,replace  = NO                                               *;
*             ,tidyup   = YES                                              *;
*             );                                                           *;
*                                                                          *;
*  NOTES : THIS PROGRAM CAN BE USED FOR RE-RUNNING BUT SHOULD NOT BE       *;
*          ADAPTED FOR ADDITIONAL DATA OR ANALYSES. THIS PROGRAM AND       *;
*          ASSOCIATED DATASETS SHOULD NOT BE PASSED ONTO ANY THIRD         *;
*          PARTIES EXCEPT REGULATORY AUTHORITIES.                          *;
*                                                                          *;
*  NOTE : FURTHER INFORMATION ON THE SAS MACRO CAN BE FOUND IN THE MACRO   *;
*         SPECIFICATION DOCUMENT CONTAINED IN                              *;
*     Q:\Central Project Resources\Generic Macros\Specification Documents  *;
*                                                                          *;
*  CHANGE HISTORY (ENSURE THAT ANY UPDATES ARE REFERENCED IN THE PROGRAM   *;
*                  WITH PROGRAMMER INITIALS AND DATE)                      *;
*                                                                          *;
*  USERID   | DATE       | CHANGE                                          *;
* ----------+------------+------------------------------------------------ *;
* WP        | 24AUG2016  | Added drop statements to _TITLES to avoid       *;
*           |            | 'over-written' appearing in the log, created as *;
*           |            | Version 3.                                      *;
*           |            | Outputted the LOG and LST file to ensure the    *;
*           |            | PAGENUM macro execution appears in the log.     *;
*           | 08SEP2016  | Update for pages >10000.                        *;
*           | 17JUL2017- | Updated to allow for OUTPUT names with brackets.*;
*           | 18JUL2017  | Updated version to PAGENUM4.                    *;
* AP        | 26JUL2024  | Renamed dataset _NULL1_ to _NULL_.              *;
*           | 16AUG2024  | Changed OUTPUT default to INPUT.                *;
*           |            | Changed PAGENUM3 default to PAGENUM1.           *;
*           |            | Added chkquotes macro to add quotes to INPUT or *;
*           |            | OUTPUT if not present and not FILEREFs.         *;
*           |            | Renamed variables _PAGES to _PAGE, _PAGES2 to   *;
*           |            | _PAGETOT, _i to _PAGEID, _j to _TABLEID.        *;
*           |            | Tidied _TITLES, _TITLES2, and _TITLES3.         *;
*           |            | Replaced goto after every validation check with *;
*           |            | local macro variable which allows all checks to *;
*           |            | complete before termination.                    *;
*           |            |                                                 *;
****************************************************************************;

%macro pagenum5(input    = "&outdir.\&outfile."
               ,output   = &input
               ,pagenum1 = Protocol:
               ,pagenum2 = &tabno.
               ,pagenum3 = &pagenum1
               ,cont1    = (continued)
               ,cont2    = (continued on next page)
               ,linesize = &ls
               ,replace  = NO
               ,tidyup   = YES
               );

    %*******************************************; 
    %*** Detail local macro variables        ***;
    %*******************************************;
    %local _lstlog terminate;
    %let terminate=0;
    
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
    %pcheckyn1(param=replace);
    %if &_skip=1 %then %let terminate=1;
    %pcheckyn1(param=tidyup);
    %if &_skip=1 %then %let terminate=1;
    
    %*AP 16AUG2024 - improved validation;
    %*Create temporary copies without quotes to allow checks to occur;
    data _null_;
        call symputx('_input',  compress("%nrbquote(&input)",  '"'), 'L');
        call symputx('_output', compress("%nrbquote(&output)", '"'), 'L');
    run;
    
    %*check INPUT;
    %if %nrbquote(&_input) eq %then %do;
        %put %str(ERR)OR: Macro parameter INPUT is blank.;
        %let terminate=1;
    %end;
    %else %if not %sysfunc(fileexist(%nrbquote(&_input))) and %sysfunc(fileref(%substr(%nrbquote(&_input)%str(        ),1,8))) ne 0 %then %do;
        %*AP 16AUG2024 - amended fileref check to truncate to 8 characters to avoid truncation message, padding the substr with 8 spaces to avoid in-valid message;
        %put %str(ERR)OR: INPUT is not a file reference or a valid file path.;
        %let terminate=1;
    %end;
    
    %*check OUTPUT path by removing filename;
    %let _output = %sysfunc(tranwrd(%nrbquote(&_output),/,\));
    %if %index(%nrbquote(&_output),\) %then %let _output=%sysfunc(tranwrd(%nrbquote(&_output),\%scan(%nrbquote(&_output),-1,\),%str()));
    %if %nrbquote(&output) eq %then %do;
        %put %str(ERR)OR: Macro parameter OUTPUT is blank.;
        %let terminate=1;
    %end;
    %else %if not %sysfunc(fileexist(%nrbquote(&_output))) and %sysfunc(fileref(%substr(%nrbquote(&_output)%str(        ),1,8))) > 0 %then %do;
        %*AP 16AUG2024 - amended fileref check to truncate to 8 characters to avoid truncation message, padding the substr with 8 spaces to avoid in-valid message;
        %put %str(ERR)OR: OUTPUT is not a valid file reference or a valid file path.;
        %let terminate=1;
    %end;
    %else %if %sysfunc(fileref(%substr(%nrbquote(&_output)%str(        ),1,8))) < 0 %then %do;
        %*if output is a fileref but file does not exist then resolve with pathname and remove filename as above;
        %let _output = %sysfunc(tranwrd(%sysfunc(pathname(%nrbquote(&output))),/,\));
        %if %index(%nrbquote(&_output),\) %then %let _output=%sysfunc(tranwrd(%nrbquote(&_output),\%scan(%nrbquote(&_output),-1,\),%str()));
        %if not %sysfunc(fileexist(%nrbquote(&_output))) %then %do;
            %put %str(ERR)OR: OUTPUT is not a valid file reference or a valid file path.;
            %let terminate=1;
        %end;
    %end;    

    %*AP 16AUG2024 - improved validation and added check for the maximum linesize of a SAS output;
    %*check LINESIZE;
    %if &linesize eq or %sysfunc(notdigit(0&linesize)) %then %do;
        %put %str(ERR)OR: Macro parameter LINESIZE must be a positive integer.;
        %let terminate=1;
    %end;
    %else %if %eval(&linesize) le 0 or %eval(&linesize)>256 %then %do;
        %put %str(ERR)OR: Macro parameter LINESIZE must be a positive integer between 1 and 256.;
        %let terminate=1;
    %end;

    %*AP 16AUG2024 - converted validation to macro;
    %macro chkblank(param=);
        %if %nrbquote(&&&param) eq %then %do;
            %put %str(ERR)OR: Macro parameter %upcase(&param) must be assigned a value.;
            %let terminate=1;
        %end;
    %mend chkblank;
    %*check PAGENUM/CONT parameters;
    %chkblank(param=pagenum1);
    %chkblank(param=pagenum2);
    %chkblank(param=pagenum3);
    %chkblank(param=cont1);
    %chkblank(param=cont2);

    %*AP 16AUG2024 - if validation failed then terminate;
    %if &terminate=1 %then %goto _quit;

    %*AP 16AUG2024 - added macro which checks for quotes in INPUT or OUTPUT and adds them if missing, unless they are FILEREFs;
    %macro chkquotes(param=);
        %*check for filerefs;
        %if %length(&&&param)<=8 %then %do;
            %if %sysfunc(fileref(&&&param))=0 %then %goto end_of_chk;
        %end;
        %*check for double (34) or single (39) quotes, use nrbquote and byte function to avoid quote characters causing issues;
        %if not (%nrbquote(%substr(&&&param,1,1))=%nrbquote(%sysfunc(byte(34))) and %nrbquote(%substr(&&&param,%length(&&&param),1))=%nrbquote(%sysfunc(byte(34))))
        and not (%nrbquote(%substr(&&&param,1,1))=%nrbquote(%sysfunc(byte(39))) and %nrbquote(%substr(&&&param,%length(&&&param),1))=%nrbquote(%sysfunc(byte(39))))
        %then %let &param="&&&param";
        %end_of_chk:
    %mend chkquotes;
    %chkquotes(param=input);
    %chkquotes(param=output);
    
    %***********************************************************************************************;
    %*** Read in data from &input file, create ordering variable _pageid to identify each of the ***;
    %*** different pages of the table - based on the assumption that the each new page will      ***;
    %*** start with the string contained in macro variable PAGENUM1                              ***;
    %***********************************************************************************************;

    %*AP 16AUG2024 - added ignoredoseof and encoding=any;
    data _output;
        length _line $ 200;
        infile &input truncover end=last ignoredoseof encoding=any;
        input _line $char200.;
        if index(_line, "&pagenum1") then _pageid+1;
    run;

    %************************************************************************************************;
    %*** Step to check whether the output dataset is empty (i.e. if the table file was completely ***;
    %*** blank) and to run the page numbering part only if the dataset exists                     ***;
    %************************************************************************************************;

    %*AP 16AUG2024 - replaced redundant code with sysnobs;
    %if &sysnobs %then %do;

        %*******************************************************************************************;
        %*** select just the lines from the table that identify the tables - based on assumption ***;
        %*** that the table number will do this and will be on a line beginning with the string  ***;
        %*** contained in macro variable PAGENUM2                                                ***;
        %*******************************************************************************************;
        data _titles;
            set _output;
            if index(_line, "&pagenum2");
        run;

        %*********************************************************************************************;
        %*** create ordering variable _tableid to determine how many different tables in the file  ***;
        %*** and page number variable _page to give the page number within each unique table       ***;
        %*********************************************************************************************;
        data _titles2(keep=_pageid _tableid _page); 
            retain _page _tableid 0;
            set _titles;
            if _line ne lag(_line) then do;
                _page=1;
                _tableid=_tableid+1;
            end;
            else _page=_page+1;
        run;

        %*******************************************************;
        %*** create page number variable _pagetot to give    ***; 
        %*** the total number of pages for each unique table ***; 
        ********************************************************;
        data _titles3(keep=_tableid _pagetot);
            set _titles2;
            by _tableid;
            _pagetot=_page;
            if last._tableid;
        run;

        %*********************************************************;
        %*** merge _titles2 and _titles3 to create one dataset ***;
        %*** with the variables _pageid, _page, and _pagetot   ***; 
        %*********************************************************;
        data _titles(keep=_pageid _page _pagetot);
             merge _titles2 _titles3;
             by _tableid;
        run;

        proc sort data=_titles nodupkey;
            by _pageid _page _pagetot;
        run;

        %***************************************************************************************;
        %*** Merge titles back with output and add some words to the first line of each table***;
        %*** to fill in the page numbers based on _page and _pagetot.                        ***;
        %*** Also removed the text &CONT1 from the title on the first page if it exists and  ***;
        %*** add the text &CONT2 to all pages except the last                                ***;
        %***************************************************************************************;
        
        %*AP 26JUL2024 - renamed _null1_ to _null_;
        %*AP 16AUG2024 - renamed z1 to pn3pos and z2 to _newline for clarity;
        %*AP 16AUG2024 - increased length of z2/_newline from 100 to 256;
        data _null_;
            length pagebit $10 _newline $256;
            retain pn3pos;
            file &output;
            merge _output _titles;
            by _pageid;
            
            %*if PAGENUM3 is detected then add Page X of Y;
            if index(_line, "&pagenum3") then do;
                %*pn3pos is location of PAGENUM3 in the line, _newline is the line truncated at PAGENUM3;
                pn3pos = index(_line, "&pagenum3");
                %*AP 16AUG2024 - moved handling of replace here to significantly condense code;
                %if &replace=NO %then %do;
                    _newline=_line;
                %end;
                %else %do;
                    if pn3pos = 1 then _newline = ' ';
                    else _newline = substr(_line, 1,(pn3pos-1));
                %end;
                %*AP 16AUG2024 - condensed significantly;
                pagebit = 'Page '||strip(put(_page, best.));

                %***append 'Page X of Y'***;
                %*AP 16AUG2024 - condensed significantly;
                %*the -5 is to make room for " of " plus the first digit which is not counted by floor(log10);
                n=&linesize-length(trim(_newline))-length(trim(pagebit))-5-floor(log10(_pagetot));
                if _N_=1 then n=n-1;
                _line=trim(_newline)||repeat(' ',n)||trim(pagebit)||" of "||strip(put(_pagetot, best.));
            end;
            
            %*remove CONT1 from the first page and replace LAST LINE footnote;
            if index(_line, "&CONT1") and _page=1 then _line = substr(_line, 1, (index(_line, "&CONT1") -1));
            else if strip(_line)="LAST LINE" then do;
                if _page ne _pagetot then _line = "&CONT2";
                else _line=' ';
            end;

            %*output modified file;
            put _line $char200.;
        run;
    %end;

    %*************************************************************;
    %*** If requested delete datasets created by PAGENUM macro ***;
    %*************************************************************;
    %if &tidyup=YES %then %do;
        proc datasets lib=work nolist nodetails memtype=data;
            delete _output _titles _titles2 _titles3;
        quit;
    %end;

    %_quit:

    %*if the LOG and LST files were output at the start of the macro now close them again;
    %if &_lstlog = Y %then %do;
        proc printto;
        run;
    %end;

%mend pagenum4;
