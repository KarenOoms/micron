*****************************Quanticate******************************;
*                                                                   *;
*  MACRO NAME       : repend1.sas                                   *;
*  AUTHOR           : Daniel Checketts (DC)                         *;
*                                                                   *;
*  CREATION DATE    : 11AUG2011                                     *;
*  RELEASE DATE     : 11JUL2024                                     *;
*                                                                   *;
*  LOCATION         : Q:\Central Project Resources\Generic Macros   *;
*                     \Validated Macros                             *;
*                                                                   *;
*  ADAPTED FROM     : N/A                                           *;
*                                                                   *;
*  PURPOSE          : Indicates the end of the program using PROC   *;
*                     PRINTTO to stop the printing of SAS output    *;
*                     and the SAS log to external files.            *;
*                                                                   *;
*  MACRO PARAMETERS :                                               *;
*            ENDLOG - Optional. Specify whether to end the log file.*;
*                     The default is YES.                           *;
*                                                                   *;
*  OUTPUT FILES : N/A                                               *;
*                                                                   *;
*  ASSUMPTIONS : The use of repend assumes that all the printing to *;
*                external files should be stopped.                  *;
*                                                                   *;
*  EXAMPLE MACRO CALL : %repend1                                    *;
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
* AP        | 11JUJ2024  | Split proc printto so that the log       *;
*           |            | is only ended if required.               *;
*           |            |                                          *;
*********************************************************************;

%macro repend2(endlog=YES);

    proc printto
        print=print
        %if %upcase(&endlog)=Y or %upcase(&endlog)=YES %then %do; log=log %end;
        ;
    run;

%mend repend1;

**END OF PROGRAM**;