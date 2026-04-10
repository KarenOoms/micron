*****************************Quanticate******************************;
*                                                                   *;
*  MACRO NAME       : repstart1.sas                                 *;
*  AUTHOR           : Daniel Checketts (DC)                         *;
*                                                                   *;
*  CREATION DATE    : 15DEC2009                                     *;
*  RELEASE DATE     : 11AUG2011                                     *;
*                                                                   *;
*  LOCATION         : J:\Statistics\Public\Fixed Fee Department\    *;
*                      Macros\Non-validated macros                  *;
*                                                                   *;
*  ADAPTED FROM     : N/A                                           *;
*                                                                   *;
*  PURPOSE          : The purpose of repstart is to indicate that   *;
*                     any SAS output to follow will be TLF output.  *;
*                     Repstart uses a PROC PRINTTO to start printing*;
*                     the SAS output to a specified external file,  *;
*                     with the correct directory and filename       *;
*                     obtainable from the use of the mindex macro   *;
*                     prior to repstart.                            *;
*                                                                   *;
*  MACRO PARAMETERS :                                               *;
*      NEW - Whether to replace or create an existing or new file   *;
*           ('new') or append to an existing file (null).           *;
*                                                                   *;
*     OUTD - Directory path to store output                         *;
*                                                                   *;
*     OUTF - Name and file extension of output file                 *;
*                                                                   *;
*  OUTPUT FILES : Defined by the macro parameters                   *;
*                                                                   *;
*  ASSUMPTIONS : The decimal macro assumes that continuous variables*;
*                will be presented as follows:                      *;
*                Minimum and maximum values will be presented to the*;
*                same decimal precision as the raw values, the mean *; 
*                and median values to one more, and the standard    *;
*                deviation, to two more decimal places than the raw *; 
*                values.                                            *;
*                                                                   *;
*  EXAMPLE MACRO CALL : %repstart1(NEW=new)                         *;
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
*           |            |                                          *;
*           |            |                                          *;
*           |            |                                          *;
*           |            |                                          *;
*           |            |                                          *;
*           |            |                                          *;
*           |            |                                          *;
*********************************************************************;

%macro repstart1(new    = new
                 , outd = &outdir
                 , outf = &outfile
                );

  proc printto print="&outd.\&outf." &new.;
  run;

%mend repstart1;

**END OF PROGRAM**;
