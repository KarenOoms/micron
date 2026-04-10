*********************************Quanticate**********************************;
*                                                                           *;
*  PROGRAM NAME      : txttortf1.sas                                        *;
*  SAS VERSION       : 9.4                                                  *;
*  AUTHOR            : John Hennessy (JH)                                   *;
*                                                                           *;
*  CREATION DATE     : 09MAY2014                                            *;
*  RELEASE DATE      : 20SEP2024                                            *;
*                                                                           *;
*  LOCATION          : Q:\Central Project Resources\Generic Macros\         *;
*                      Validated Macros\                                    *;
*                                                                           *;
*  ADAPTED FROM      : NA.                                                  *;
*                                                                           *;
*  PURPOSE           : Create RTF output from text input that follows       *;
*                      Client Q_024 standards.                              *;
*                                                                           *;
*  MACRO PARAMETERS  :                                                      *;
*  IND         - Optional. The directory containing the source file, with   *;
*                or without a trailing slash character. The default value   *;
*                is &OUTDIR.                                                *;
*  INF         - Optional. The name and file extension of the source file.  *;
*                The default value is &OUTFILE.                             *;
*  INDOC       - Optional. The file extension of the source file, used      *;
*                only when IND=OUTD and INF=OUTF. The default value is TXT. *;
*  OUTD        - Optional. The directory to save the output file in, with   *;
*                or without a trailing slash character. The default value   *;
*                is &OUTDIR.                                                *;
*  OUTF        - Optional. The name and file extension of the output file,  *;
*                this must end with .rtf unless IND=OUTD and INF=OUTF. The  *;
*                default value is &OUTFILE.                                 *;
*  FONT        - Optional. The font to use in the output file. The default  *;
*                value is Courier New.                                      *;
*  FONTSIZE    - Optional. The font size to use in the output file. The     *;
*                default value is 9.                                        *;
*  BMARGIN     - Optional. The size of the bottom margin of the page,       *;
*                including unit. The default value is 2.57cm.               *;
*  TMARGIN     - Optional. The size of the top margin of the page,          *;
*                including unit. The default value is 3.00cm.               *;
*  RMARGIN     - Optional. The size of the right margin of the page,        *;
*                including unit. The default value is 2.01cm.               *;
*  LMARGIN     - Optional. The size of the left margin of the page,         *;
*                including unit. The default value is 2.05cm.               *;
*  ORIENTATION - Optional. Specifies whether the page orientation of the    *;
*                produced RTF file is PORTRAIT or LANDSCAPE. P or L are     *;
*                also accepted. The default value is &ORIENT.               *;
*  TIDYUP      - Optional. Specifies whether to delete temporary datasets   *;
*                created by the macro. The default value is YES.            *;
*                                                                           *;
*  OUTPUT FILES : The RTF file specified by OUTD and OUTF.                  *;
*                                                                           *;
*  ASSUMPTIONS : The default values for macro parameters assume that the    *;
*                (N)MINDEX macro has been run to define &OUTDIR, &OUTFILE,  *;
*                and &ORIENT.                                               *;
*                                                                           *;
*  EXAMPLE MACRO CALL : %txttortf1;                                         *;
*                                                                           *;
*  NOTES : THIS PROGRAM CAN BE USED FOR RE-RUNNING BUT SHOULD NOT BE        *;
*          ADAPTED FOR ADDITIONAL DATA OR ANALYSES. THIS PROGRAM AND        *;
*          ASSOCIATED DATASETS SHOULD NOT BE PASSED ONTO ANY THIRD PARTIES  *;
*          EXCEPT REGULATORY AUTHORITIES.                                   *;
*                                                                           *;
*  NOTE : FURTHER INFORMATION ON THE SAS MACRO CAN BE FOUND IN THE MACRO    *;
*         SPECIFICATION DOCUMENT CONTAINED IN                               *;
*     Q:\Central Project Resources\Generic Macros\Specification Documents   *;
*                                                                           *;
*  CHANGE HISTORY (ENSURE THAT ANY UPDATES ARE REFERENCED IN THE PROGRAM    *;
*                  WITH PROGRAMMER INITIALS AND DATE)                       *;
*                                                                           *;
*  USERID   | DATE       | CHANGE                                           *;
* ----------+------------+------------------------------------------------- *;
*  AP       | 20SEP2024  | Added FONT and FONTSIZE parameters with defaults *;
*           |            | of the original values.                          *;
*           |            | Resolved log messages.                           *;
*           |            |                                                  *;
*****************************************************************************;

%macro txttortf2(ind         = &outdir.
                ,inf         = &outfile.
                ,indoc       = txt
                ,outd        = &outdir.
                ,outf        = &outfile.
                ,font        = Courier New
                ,fontsize    = 9
                ,bmargin     = 2.57cm
                ,tmargin     = 3.00cm
                ,rmargin     = 2.01cm
                ,lmargin     = 2.05cm
                ,orientation = &orient.
                ,tidyup      = YES
                );

    %* Standardisation of macro variable values;
    %let indoc   = %upcase(&indoc.);
    %let tidyup  = %upcase(&tidyup.);
    %if       %index(&tidyup.,Y) %then %let tidyup = YES;
    %else %if %index(&tidyup.,N) %then %let tidyup = NO;
    %let orientation = %upcase(&orientation.);
    %if       %index(&orientation.,P) %then %let orientation = portrait;
    %else %if %index(&orientation.,L) %then %let orientation = landscape;
    
    %* Separator for file paths;
    %if &sysscp=WIN %then %let _sep=\;
    %else %let _sep=/;

   %* location of style;
   ods path work.template(write) sashelp.tmplmst(read);

   %* define escape character;
   ods escapechar='^';

    %* create style;
    proc template;
        define style styles.watermark / store=work.template;
        parent=styles.printer;
        style body from document /
              background=_undef_;
        end;
    run;

    %* reset titles and footnotes;
    title;
    footnote;

    %* options for rtf output;
    options formchar="|____|||___" 
            nobyline 
            leftmargin=&lmargin. 
            topmargin=&tmargin. 
            rightmargin=&rmargin. 
            bottommargin=&bmargin. 
            pagesize=&ps. 
            linesize=&ls. 
            orientation=&orientation.
    ;

    %* close output;
    %*AP 20SEP2024 - changed to ods results due to err-or;
    /*ods listing select none;*/
    ods results off;

    %* start rtf file;
    %if ("&outf." = "&inf." and "&outd." = "&ind.") %then %do;
        ods rtf file="&outd.&_sep.%qtrim(%sysfunc(tranwrd(%lowcase(&inf.),%lowcase(.&indoc.),))).rtf" style=watermark;
    %end;
    %else %do;
        ods rtf file="&outd.&_sep.&outf." style=watermark;
    %end;

     %* Read in the text file;
     %let file="&ind.&_sep.&inf";

    data _tmp;
        length text $255;
        infile &file. missover length=RECORDLENGTH;
        input text $varying. RECORDLENGTH @;
        retain page 0;
        if substr(text,1,1) eq '0C'x then do;
            %* set page breaks;
            page=page+1;
            %* remove page breaks from text;
            text=substr(text,2);
        end;
    run;
  
    %* report listing;
    %* AP 20SEP2024 - changed page from group to order to resolve a log note;
    proc report data=work._tmp 
                nowindows 
                noheader 
                missing 
                contents=""
                style(column) = {font_face="&font" font_size=&fontsize.pt}
                style(report) = {rules=none cellspacing=0 cellpadding=0 borderwidth=0};
        column page text ;
        define page / noprint order;
        define text / display style(column)={asis=on} "";
        break after page / page;
    run;

    %* close rtf output;
    ods rtf close;
    %*AP 20SEP2024 - changed to ods results due to err-or;
    /*ods listing select all;*/
    ods results on;

    %* tidy up;
    %if &tidyup=YES %then %do;
        proc datasets lib=work nolist;
           delete _tmp;
        quit;
    %end;

    %exit:

%mend txttortf1;