*****************************Quanticate******************************;
*                                                                   *;
*  MACRO NAME       : pagebrk3.sas                                  *;
*  AUTHOR           : William Paget (WP)                            *;
*                                                                   *;
*  CREATION DATE    : 14MAR2016                                     *;
*  RELEASE DATE     : 19SEP2024                                     *;
*                                                                   *;
*  LOCATION         : Q:\Central Project Resources\Generic Macros\  *;
*                     Validated Macros                              *;
*                                                                   *;
*  ADAPTED FROM     : PAGEBRK2                                      *;
*                                                                   *;
*  PURPOSE          : Text tables often run over several pages.     *;
*                     A variable is often derived to break the proc *;
*                     report in an appropriate place.               *;
*                                                                   *;
*                     This macro replaces a numeric variable (PAGE) *;
*                     that can be used in proc report.  Page is in  *;
*                     the format 1, 2, 3, 4 etc. which increases    *;
*                     within the dataset depending on the page size *;
*                     of the report (excluding titles, footnotes and*;
*                     headers) and the width of the 1st column      *;
*                     (COL0) (usually containing text that may break*;
*                     on to new lines, e.g. adverse events, medical *;
*                     history etc).  A variable ORDER can be used,  *;
*                     which the macro takes into account and doesnt *;
*                     break within that variable unless it has to   *;
*                     due to it not fitting on one page.            *;
*                                                                   *;
* MACRO PARAMETERS  :                                               *;
*    DSIN - Input dataset name (containing a column COL0).          *;
*     OUT - Name of the output dataset. Default is &DSIN.           *;
*   ORDER - Name of the order variable that breaks need to account  *;
*           for. Default is order.                                  *;
*PAGESIZE - The number of lines available on the report. Note that  *;
*           this is after taking in to account titles, footnotes and*;
*           column headers. For example, if the global page size is *;
*           45 and the number of lines of titles, footnotes and     *;
*           headers (including any blank lines and horizontal lines *;
*           (e.g. ______)) is 12, then &pagesize should be a maximum*;
*           of 45 - 12 - 1 = 32.                                    *;
*           Note, as a guide the following are roughly correct:     *;
*                 Landscape - pagesize of 25 - 30                   *;
*                  Portrait - pagesize of 45 - 50                   *;
*  SORTBY - The variables that the output should be sorted by.      *;
*   NPVAR - This specifies a variable where different levels of the *;
*           variable must be on a different page.                   *;
*   WIDTH - Width of the col0 column in the proc report. Default is *;
*           &w_0 macro parameter from COLWIDTH macro                *;
*  ADDCONT - If YES then if an ORDER runs over multiple lines the   *;
*            first row in the ORDER will be repeated with           *;  
*            '(continued)' added to COL0                            *;
*  TIDYUP - Whether temporary datasets created by the macro should  *;
*           be deleted or not.                                      *;  
*  OUTPUT FILES : N/A                                               *;
*                 Output dataset specified by macro parameter OUT   *;
*                 is created.                                       *;
*                                                                   *;
*  ASSUMPTIONS : This macro replaces a variable (PAGE) that can be  *;
*                used in proc report.  However this macro cannot    *;
*                deal with all situations and minor adjustments to  *;
*                PAGE may be required after the macro is run. Note  *;
*                that the variable PAGE must exist within the input *;
*                dataset                                            *;
*                The macro assumes that a character variable COL0 is*;
*                contained within the input dataset. The reason for *;
*                this is that this variable would usually contain   *;
*                text that may break on to new lines depending on   *;
*                its width within the proc report.  If there are    *;
*                other columns that contain text that breaks over   *;
*                multiple lines the macro will not adjust for these *;
*                The macro assumes that there will be a  break after*;
*                &order / skip  in the proc report and adjusts for  *;
*                these blank lines.  If the standard REPORT macro is*;
*                being used the &ORDER parameter should be specified*;
*                as ORDER to ensure that the skip is added.         *;
*                                                                   *;
*  EXAMPLE MACRO CALL : %pagebrk3(dsin=final1,out=final2,order=order*;
*          ,pagesize=25,sortby=order index,width=30,tidyup=YES)     *;
*          ,tidyup=YES)                                             *;
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
* WP        | 28NOV2016- | Added ADDCONT to the macro, resolved     *;
*           | 14DEC2016  | issue where the page-breaking did not    *;
*           |            | Updated from PAGEBRK2 to PAGEBRK3        *;
*           |            | occur as expected                        *;
* AP        | 19SEP2024  | Corrected TIDYUP dataset list.           *;
*           |            |                                          *;
*********************************************************************;

%macro pagebrk4(dsin       =
                , out      = &dsin
                , order    = order
                , pagesize = &ps
                , sortby   = order
                , npvar    = 
                , width    = &w0_1
                , addcont  = YES
                , tidyup   = YES
               );

    /*******************************************;/ 
    /*** Detail global local variables       ***/
    /*******************************************/
    %local _ordtype _dsetin _maxinord _maxrow _npvtype _col0type _maxlen
        ;

    %let _dsetin = %scan(%bquote(&dsin), 1, %str(%());

    %let npvar = %upcase(&npvar);
    %let order = %upcase(&order);
    %let sortby = %upcase( %cmpres(&sortby) );

    /*** macro parameter checking ***/
    %if &dsin= %then %do;
        data _null_;
            put "ERR" "OR: Macro parameter DSIN has " "not been specified.";
        run;
        %goto here;
    %end;
    %if %bquote(&out) = %then %do;
        data _null_;
            put "ERR" "OR: Macro parameter OUT has " "not been specified.";
        run;
        %goto here;
    %end;
    %if %sysfunc(exist(&_dsetin))=0 %then %do;
        data _null_;
            put "ERR" "OR: Dataset &_dsetin does not exist.";
        run;
        %goto here;
    %end;
    %if &sortby= %then %do;
        data _null_;
            put "ERR" "OR: Macro parameter SORTBY has " "not been specified.";
        run;
        %goto here;
    %end;
    %if &order= %then %do;
        data _null_;
            put "ERR" "OR: Macro parameter ORDER has " "not been specified.";
        run;
        %goto here;
    %end;
    %if &width= %then %do;
        data _null_;
            put "ERR" "OR: Macro parameter WIDTH has " "not been specified.";
        run;
        %goto here;
    %end;
    %if %eval(&width) le 0 %then %do;
        data _null_;
            put "ERR" "OR: Macro parameter WIDTH must be a positive integer.";
        run;
        %goto here;
    %end;
    %if &pagesize= %then %do;
        data _null_;
            put "ERR" "OR: Macro parameter PAGESIZE has " "not been specified.";
        run;
        %goto here;
    %end;
    %if %eval(&pagesize) le 0 %then %do;
        data _null_;
            put "ERR" "OR: Macro parameter PAGESIZE must be a positive integer.";
        run;
        %goto here;
    %end;
    %if %nrbquote(&npvar) ^= %scan(%nrbquote(&npvar), 1, %str( )) %then %do;
        data _null_;
            put "ERR" "OR: Macro parameter NPVAR can only contain a single variable.";
        run;
        %goto here;
    %end;
    %pcheckyn1(param = tidyup);
    %if &_skip = 1 %then %goto here;
    %pcheckyn1(param = addcont);
    %if &_skip = 1 %then %goto here;

    data _null_;
        format type col0type %if &npvar ^= %then npvtype; $3. ; 
        dsid=open("&_dsetin",'i');
        vnum=varnum(dsid,"&order");
        if vnum ne 0 then type=vartype(dsid,vnum);
        col0vnum=varnum(dsid,"col0");
        if col0vnum ne 0 then col0type=vartype(dsid,col0vnum);
        %if &npvar ^= %then %do;
            npvnum=varnum(dsid,"&npvar");
            if npvnum ne 0 then npvtype=vartype(dsid,npvnum);
        %end;
        rc=close(dsid); 
        call symput('_ordtype', type);
        call symput('_col0type', col0type);
        %if &npvar ^= %then %do;
            call symput('_npvtype', npvtype);
        %end;
    run;

    %if &_ordtype= %then %do;
        data _null_;
            put "ERR" "OR: Specified input dataset &_dsetin" " does not contain specified variable &order..";
        run;
        %goto here;
    %end;
    %if &_col0type= %then %do;
        data _null_;
            put "ERR" "OR: Specified input dataset &_dsetin" " does not contain COL0.";
        run;
        %goto here;
    %end;
    %if &_npvtype= and &npvar ^= %then %do;
        data _null_;
            put "ERR" "OR: Specified input dataset &_dsetin" " does not contain specified variable &npvar..";
        run;
        %goto here;
    %end;

    /*** Check SORTBY contains ORDER and NPVAR ***/
    %if ^(%scan(&sortby, 1, %str( )) = &order or %scan(&sortby, -1, %str( )) = &order or
        %sysfunc(indexw(&sortby, %str( &order )))) %then %do;
        data _null_;
            put "ERR" "OR: Macro parameter ORDER (&order) does not appear in SORTBY (&sortby).";
        run;
        %goto here;
    %end;
    %if ^(%scan(&sortby, 1, %str( )) = &npvar or %scan(&sortby, -1, %str( )) = &npvar or
        %sysfunc(indexw(&sortby, %str( &npvar )))) and &npvar ^= %then %do;
        data _null_;
            put "ERR" "OR: Macro parameter NPVAR (&npvar) does not appear in SORTBY (&sortby).";
        run;
        %goto here;
    %end;

    proc sort data = &dsin out = _pagebrk1;
        by &sortby;
    run;

    proc sql noprint;
        select max( length(col0) ) into :_maxlen from _pagebrk1;
    quit;
    %let _maxlen = %eval(&_maxlen + 1);

    *** For each row in the dataset calculate how many rows in a table it will cover (_lines) ***;
    *** Then sum these for each order ***;
    data _pagebrk2;
        length _tempcol0 $200.;
        set _pagebrk1;
        by &sortby;
        _tempcol0 = '';
        if index(col0, '|') then _lines = count(col0, '|') + 1;
        else if length(col0) le &width then _lines = 1;
        else do;
            _remain = col0;
            _lines = 1;
            %do _i = 1 %to &_maxlen;
                _remain = strip( substr(_remain, &width - index( reverse( substr(_remain, 1, &width) ) , ' ') + 1 ) );
                if _remain ^= '' then do;
                    _lines = _lines + 1;
                    _remain1 = _remain;
                end;
            %end;
        end;
        %if %bquote(&npvar) ^= %then %do;
            if first.&npvar then _npvarf = 1;
        %end;
        %else %do;
            if _n_ = 1 then _npvarf = 1;
        %end;
        if last.&order then _lastord = 1;
        _lines1 = 0;
        %if &addcont = YES %then %do;
            if first.&order then do;
                _tempcol0 = strip(col0) || ' (continued)';
                if _remain1 ^= '' and length(_remain1) gt %eval(&width - 12) then _lines1 = _lines + 1;
                else if index(col0, '|') and length( scan(col0, -1, '|') ) gt %eval(&width - 12) then _lines1 = _lines + 1;
                else if ^index(col0, '|') and _remain1 = '' and length(col0) gt %eval(&width - 12) then _lines1 = _lines + 1;
                else _lines1 = _lines;
            end;
        %end;
        _totrow = _n_;
    run;

    *** Output ORDER, _NUM and _NPVAR as macro variables ***;
    proc sql noprint;
        select max(_totrow) into :_totrow from _pagebrk2;
        %let _totrow = &_totrow;
        select _totrow, &order, _lines, _lines1, _npvarf, _lastord into :_null1 - :_null&_totrow,  :_ordpbk1 - :_ordpbk&_totrow, 
            :_numpbk1 - :_numpbk&_totrow, :_numpbkac1 - :_numpbkac&_totrow, :_npvpbk1 - :_npvpbk&_totrow, :_lorpbk1 - :_lorpbk&_totrow from _pagebrk2 order by _totrow;
    quit;

    *** Specify the macro parameters to start with, then work out the associated page each time ***;
    %do _i = 1 %to &_totrow;
        %if &addcont = YES %then %let _costpbk&_i = 0; /* Identifies the row to add in, set as blank to start */
        %if &&_npvpbk&_i = 1 %then %do; 
            /* For the first NPVAR everything should be restarted */
            %let _cpgpbk = 1; /* Current page number */
            %let _cordpbk = %bquote(&&_ordpbk&_i); /* Current order number */
            %let _sordpbk = %bquote(&_cordpbk); /* Order number at the start of the page */
            %let _clnspbk = 0; /* Current number of lines in this page */
            %let _costpbk = &_i; /* Start number of current order */
            %let _rmnpbk = 0; /* The amount of space remaining on the previous page */
            %let _cnstpbk = ; /* The number of lines used up at the end of the previous order */
            %let _nofpbk = 1; /* Flag that shows a new order started (may get changed below) */
            /* _PAGEPBK1 - X - Contains the calculated page number for the dataset row */
        %end;
        %let _clnspbk = %eval(&_clnspbk + &&_numpbk&_i); /* Add on the number of table rows taken up by the latest dataset row */
        %if %bquote(&_cordpbk) ^= %bquote(&&_ordpbk&_i) %then %do; /* New order starts */
            %let _cordpbk = %bquote(&&_ordpbk&_i); /* Select the new order */
            %let _costpbk = &_i; /* The start number of the current order */
            %let _cnstpbk = %eval(&_clnspbk - &&_numpbk&_i); /* Reset the number of lines used up at the end of the previous order */
            %let _nofpbk = 1; /* Flag that shows a new order started (may get changed below) */
        %end;
        /* Page number continues */
        %if &_clnspbk le &pagesize %then %do;
            %let _pagepbk&_i = &_cpgpbk; 
        %end;
        %else %do; /* New page number starts */
            /* (&_costpbk ^= &_i) checks the row is not the first row in an order, 
                    (&_sordpbk ^= &&_ordpbk&_i) checks that the order number has changed since the start of the page;
            /* The order is not spanning multiple pages */
            %if &_costpbk ^= &_i and %bquote(&_sordpbk) ^= %bquote(&&_ordpbk&_i) %then %do; 
                %let _rmnpbk = %eval(&pagesize - &_cnstpbk); /* The amount of space remaining on the previous page */
                %let _cpgpbk = %eval(&_cpgpbk + 1); /* Current page number increases by 1 */
                %let _i = &_costpbk; /* Go back to the start number of the current order */
                %let _clnspbk = &&_numpbk&_i; /* The number of lines on the page restarts */
                %let _pagepbk&_i = &_cpgpbk; /* Page number set (this has been increased by 1 already) */
                %let _sordpbk = %bquote(&&_ordpbk&_i); /* Order number at the start of the page */
                %let _nofpbk = 1; /* Flag that shows a new order started (may get changed below) */
            %end;
            %else %do;
            /* Code from here covers when order number has remained constant on a page, or the new page is just starting */
                /* (&_costpbk ^= &_i) checks the row is not the first row in an order, 
                    (&_rmnpbk ge 4) checks there is sufficient room on the previous page to make it worth adding more to that page,
                        (&_nofpbk = 1) shows that the long order (which covers multiple pages) has already been checked against the previous page */
                /* This is the first time the page has wrapped, and there is room to go back */
                %if &_costpbk ^= &_i and &_nofpbk = 1 and &_rmnpbk ge 4 %then %do; 
                    %let _nofpbk = ; /* Shows the page has wrapped previously */
                    %let _cpgpbk = %eval(&_cpgpbk - 1); /* Current page number DECREASES by 1 */
                    %let _i = &_costpbk; /* Go back to the start number of the current order */
                    %let _clnspbk = %eval(&pagesize - &_rmnpbk + &&_numpbk&_i); /* The number of lines on the page continues from the previous page */
                    %let _pagepbk&_i = &_cpgpbk; /* Page number set (this has been decreased by 1 already) */
                    %let _nofpbk = ; /* Set the flag to blank to avoid looping through this again for the same order */
                %end;
                %else %do;
                /* If the new page is just starting or the order being summarized has already spread across multiple pages */
                    /* Just continue the order on the next page */
                    %let _rmnpbk = 0; /* The amount of space remaining on the previous page */
                    %let _cpgpbk = %eval(&_cpgpbk + 1); /* Current page number increases by 1 */
                    %let _clnspbk = %eval(&&_numpbk&_i); /* The number of lines on the page restarts */
                    %let _pagepbk&_i = &_cpgpbk; /* Page number set (this has been increased by 1 already) */
                    %let _sordpbk = %bquote(&&_ordpbk&_i); /* Order number at the start of the page */
                    %if &addcont = YES and &_costpbk ^= &_i %then %do;
                        %let _clnspbk = %eval(&_clnspbk + &&_numpbkac&_costpbk); /* Add on the additional lines then ADDCONT part will take up */
                        %let _costpbk&_i = &_costpbk; /* Identifies the row to add in, the first row in the order */
                    %end;
                %end;
            %end;
        %end;
        %if &&_lorpbk&_i = 1 %then %do;
            /* If it is the last in an order add 1 to account for blank row added by SKIP in PROC REPORT */
            %let _cnstpbk = %eval(&_cnstpbk + 1);
            %let _clnspbk = %eval(&_clnspbk + 1);
        %end;
    %end;

    %if &addcont = YES %then %let _pgbout = _pagebrk3;
    %else %let _pgbout = &out;

    data &_pgbout (drop = _tempcol0) _addcontrs (drop = col: rename = (_tempcol0 = col0));
        set _pagebrk2;
        * Specify the page number;
        %do _i = 1 %to &_totrow;
            if _totrow = &_i then do;
                page = &&_pagepbk&_i;
                output &_pgbout;
            end;
            %if &addcont = YES %then %do;
                %if &&_costpbk&_i ^= 0 %then %do;
                    if _totrow = &&_costpbk&_i then do;
                        page = &&_pagepbk&_i;
                        output _addcontrs;
                    end;
                %end;
            %end;
        %end;
        %if &tidyup=YES %then drop _lines _lines1 _totrow _npvarf _remain _remain1 _lastord;;
    run;

    %if &addcont = YES %then %do;
        %if %sysfunc( indexw(&sortby, %str(&order) ) ) = 1 %then %let _pgordby = ;
        %else %let _pgordby = %sysfunc(substr(&sortby, 1, %eval( %sysfunc( indexw(&sortby, %str(&order) ) ) - 2) ) );
        %put &_pgordby;

        * Add on the '(continued)' rows;
        data &out;
            set _pagebrk3 _addcontrs;
            by &_pgordby page &order &sortby;
        run;        
    %end;

    /*** Tidy up temporary datasets used by the macro ***/
    %*AP 19SEP2024 - _ADDCONTRS is always created so moved it outside the if-statement;
    %if &tidyup=YES %then %do;
        proc datasets lib = work nolist nodetails memtype = data;
            delete _pagebrk1 _pagebrk2 _addcontrs %if &addcont = YES %then _pagebrk3;;
        run;
        quit;
    %end;

    %here: 

%mend pagebrk3;
