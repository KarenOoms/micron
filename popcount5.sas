****************************************************************************;
*                                                                          *;
*  PROGRAM NAME      : popcount4.sas                                       *;
*  SAS VERSION       : 9.4 English                                         *;
*  AUTHOR            : Will Paget (WP)                                     *;
*                                                                          *;
*  CREATION DATE     : 10SEP2014                                           *;
*  RELEASE DATE      : 05NOV2024                                           *;
*                                                                          *;
*  LOCATION          : Q:\Central Project Resources\Generic Macros\        *;
*                      Validated Macros\                                   *;
*                                                                          *;
*  ADAPTED FROM      : popcount3.sas.                                      *;
*                                                                          *;
*  PURPOSE           : To create macro variables TOTn with the numbers of  *;
*                      subjects in particular groups.                      *;
*                                                                          *;
*  MACRO PARAMETERS  :                                                     *;
*  DSIN    - Required. The dataset containing the subjects to count.       *;
*  BYVAR   - Required. A single by-variable used to define each            *;
*            population group. This must contain integers but they may be  *;
*            character or numeric.                                         *;
*  SUBJECT - Optional. One or more variables used to define each unique    *;
*            subject. The default value is USUBJID.                        *;
*  MAXCOLS - Optional. The maximum allowed number of groups. This must be  *;
*            greater than or equal to the maximum value of BYVAR. The      *;
*            default value is 9.                                           *;
*  TIDYUP  - Optional. Specifies whether to delete temporary datasets      *;
*            created by the macro. The default value is YES.               *;
*                                                                          *;
*  OUTPUT FILES : NA.                                                      *;
*                                                                          *;
*  ASSUMPTIONS : Global macro variables TOTn are created for each group    *;
*                of subjects. Any existing global macro variables with     *;
*                name consisting of 'TOT' followed by digits will be       *;
*                deleted prior to calculation.                             *;
*                                                                          *;
*                The index in the variable name is equal to the            *;
*                corresponding value of BYVAR. The total number of         *;
*                subjects in DSIN is stored in TOT(MAXCOLS+1) and the sum  *;
*                of all subject groups is stored in TOT(MAXCOLS+2). These  *;
*                two variables should be equal but may not be if any       *;
*                values of BYVAR are missing.                              *;
*                                                                          *;
*  EXAMPLE MACRO CALL :                                                    *;
*    %popcount4(dsin    = derived.adsl(where=(SAFFL='Y'))                  *;
*              ,byvar   = TRT01AN                                          *;
*              ,subject = USUBJID                                          *;
*              ,maxcols = 9                                                *;
*              ,tidyup  = YES                                              *;
*              );                                                          *;
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
*  AP       | 05NOV2024  | General code and header improvements.           *;
*           |            | Multiple subject variables are now allowed.     *;
*           |            | Pre-existing TOTn global macro variables are    *;
*           |            | now deleted if the macro executes successfully. *;
*           |            | Format best8. is no longer used so counts       *;
*           |            | >99999999 will now be correctly stored.         *;
*           |            |                                                 *;
****************************************************************************;
 
%macro popcount5(dsin     =
                ,byvar    =
                ,subject  = USUBJID
                ,maxcols  = 9
                ,tidyup   = YES
                );

    /*** Validation and Standardisation ***/
   
    %local terminate;
    %let terminate=0;
    
    *check DSIN is populated and exists, and is not empty;
    %if %nrbquote(&dsin) eq %then %do;
        %put %str(ERR)OR: DSIN must not be blank.;
        %let terminate=1;
    %end;
    %else %if not %sysfunc(exist(%scan(%nrbquote(&dsin),1,%()))) %then %do;
        %put %str(ERR)OR: Dataset "%scan(%nrbquote(&dsin),1,%())" specified in DSIN does %str(not) exist.;
        %let terminate=1;
    %end;
    %else %do;
        *create dataset with any bracketed options applied, and check that this dataset is not empty;
        data _dsin;
            set &dsin;
        run;
        %if &sysnobs=0 %then %do;
            %put %str(ERR)OR: The dataset specified in DSIN is empty.;
            %let terminate=1;
        %end;
    %end;
    
    *check SUBJECT is populated and is valid;
    *if so then standardise as uppercase with single spaces between each variable;
    %if %nrbquote(&subject) eq %then %do;
        %put %str(ERR)OR: SUBJECT must not be blank.;
        %let terminate=1;
    %end;
    %else %do;
        data _null_;
            if notname(compress("%nrbquote(&subject)")) then do;
                put 'ERR' 'OR: SUBJECT contains invalid characters.';
                call symputx('terminate', 1);
            end;
            else call symputx('subject', upcase(compbl("%nrbquote(&subject)")));
        run;
    %end;
    
    *check BYVAR is populated and is valid;
    %if %nrbquote(&byvar) eq %then %do;
        %put %str(ERR)OR: BYVAR must not be blank.;
        %let terminate=1;
    %end;
    %else %if %sysfunc(notname(%nrbquote(&byvar))) %then %do;
        %put %str(ERR)OR: BYVAR contains invalid characters, it must be a single variable name.;
        %let terminate=1;
    %end;
    %else %let byvar=%upcase(&byvar);
    
    *check MAXCOLS is integer and populated;
    %if %sysfunc(notdigit(&maxcols.0)) or %nrbquote(&maxcols) eq %then %do;
        %put %str(ERR)OR: MAXCOLS must be populated with a positive integer.;
        %let terminate=1;
    %end;
        
    *standardise and validate YES/NO parameters;
    %pcheckyn1(param=tidyup);
    %if &_skip=1 %then %let terminate=1;
    
    *validation checkpoint;
    %if &terminate=1 %then %goto end_of_macro;
    
    *obtain list of variables in DSIN;
    %local _dsinvars;
    proc sql noprint;
        select distinct upcase(NAME) into :_dsinvars separated by ' ' from dictionary.columns
        where upcase(LIBNAME)='WORK' and upcase(MEMNAME)='_DSIN';
    quit;
    
    *check SUBJECT variables are all in DSIN;
    %local i _byvalues;
    %do i=1 %to %sysfunc(countw(&subject));
        %if not %sysfunc(indexw(&_dsinvars, %scan(&subject,&i))) %then %do;
            %put %str(ERR)OR: SUBJECT variable %scan(&subject,&i) was %str(not) found in dataset DSIN.;
            %let terminate=1;
        %end;
    %end;
    *check BYVAR variable is in DSIN and check it is integer (either numeric or character);
    %if not %sysfunc(indexw(&_dsinvars, &byvar)) %then %do;
        %put %str(ERR)OR: BYVAR variable &byvar was %str(not) found in dataset DSIN.;
        %let terminate=1;
    %end;
    %else %do;
        proc sql noprint; select distinct &byvar into :_byvalues separated by '' from _DSIN; quit;
        *append 0 to allow for all values missing;
        %if %sysfunc(notdigit(&_byvalues.0)) %then %do;
            %put %str(ERR)OR: BYVAR variable &byvar contains non-integer values.;
            %let terminate=1;
        %end;
    %end;
           
    *validation checkpoint;
    %if &terminate=1 %then %goto end_of_macro;
    
    *select only unique values per subject;
    *run it here to speed up the vvalue code;
    proc sort nodupkey data=_DSIN(keep=&byvar &subject) out=_dsin_bysub;
        by &byvar &subject;
    run;
    
    *remove any records where any BYVAR values are missing;
    *set all BYVARs to numeric;
    data _dsin_bysubn;
        set _dsin_bysub;
        if not missing(&byvar);
        *create definitely numeric variable by using vvalue statement to automatically convert numeric variables to character,
        then use input statement to convert all to numeric;
        __TEMP=input(vvalue(&byvar), best.);
        *drop the old variable and replace with the new one;
        drop &byvar;
        rename __TEMP=&byvar;
    run;
    
    *check that dataset is not empty;
    %if &sysnobs=0 %then %do;
        %put %str(ERR)OR: BYVAR values are missing for all records.;
        %let terminate=1;
    %end;
    
    *check that the maximum value of the first BYVAR variable is not greater than MAXCOLS;
    %local _maxbyvalue;
    proc sql noprint; select max(&byvar) into :_maxbyvalue trimmed from _dsin_bysubn; quit;
    %if &maxcols<&_maxbyvalue %then %do;
        %put %str(ERR)OR: Maximum value of BYVAR variable &byvar is greater than MAXCOLS.;
        %let terminate=1;
    %end;
        
    *validation checkpoint;
    %if &terminate=1 %then %goto end_of_macro;
    
    /*** Obtain Counts ***/
   
    *remove all existing TOTn variables;
    %local _totvars;
    proc sql noprint;
        select distinct NAME into :_totvars separated by ' ' from sashelp.vmacro
        where upcase(SCOPE)='GLOBAL' and prxmatch('/^TOT\d+$/', strip(upcase(NAME)));
    quit;
    %symdel &_totvars;
    
    *initialise all TOTn macro variables as 0;
    data _null_;
        %local i;
        %do i=1 %to %eval(&maxcols+2);
            call symputx("tot&i", '0', 'G');
        %end;
    run;
    
    *get count for all subjects;
    proc sort nodupkey data=_dsin out=_dsin_sub;
        by &subject;
    run;
    %global tot%eval(&maxcols+1);
    %let tot%eval(&maxcols+1)=&sysnobs;
    
    *count subjects within each BYVAR;
    proc freq data=_dsin_bysubn noprint;
        tables &byvar / out=_bycounts1(drop=PERCENT);
    run;
    
    *get counts;
    data _bycounts2;
        set _bycounts1 end=final;
        
        *define the TOT suffix using the value of BYVAR;
        if COUNT>0 then call symputx('tot'||strip(put(&byvar,best.)), COUNT, 'G');
        
        *sum all the groups;
        retain SUM 0;
        SUM=sum(SUM, COUNT);
        if final then call symputx('tot'||strip(put(&maxcols+2,best.)), SUM, 'G');
    run;
    
    *check that all subjects are included in the groups;
    %local _maxc1 _maxc2;
    %let _maxc1=%eval(&maxcols+1);
    %let _maxc2=%eval(&maxcols+2);
    %if &&tot&_maxc1 ne &&tot&_maxc2 %then %do;
        %put %str(MGCH)ECK: Total number of SUBJECTs (&&tot&_maxc1) does not equal the sum of numbers in groups (&&tot&_maxc2).;
        %put %str(MGCH)ECK: This may be due to missing values in the BYVAR variables.;
    %end;
    
    /*** Tidy-up ***/

    %end_of_macro:
    
    %if &tidyup=YES %then %do;
        *get a list of all actually generated datasets;
        %local tidyup_dsets;
        proc sql noprint;
            select distinct MEMNAME into :tidyup_dsets separated by ' ' from dictionary.columns
            where upcase(LIBNAME)='WORK' and (upcase(MEMNAME) like '_DSIN%' or upcase(MEMNAME) like '_BYCOUNTS%');
        quit;
        *if any datasets were generated then delete them;
        %if &sqlobs>0 %then %do;
            proc datasets mt=data nolist lib=work;
                delete &tidyup_dsets;
            quit;
        %end;
    %end;
    
%mend popcount4;