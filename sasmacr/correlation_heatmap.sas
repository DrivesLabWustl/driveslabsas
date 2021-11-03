/******************************************************************************
* Program:     correlation_heatmap.sas                                        *
* Location:    https://github.com/RoeLabWustl/roelabsas/sasmacr               *
* Author:      Matthew Schuelke <schuelke@wustl.edu>                          *
* Created:     2021-08-08                                                     *
* Version:     2021-08-08                                                     *
* SAS Version: 9.4                                                            *
* Summary:                                                                    *
*   SAS Macro to create a correlation heatmap (cf., correlogram) by           *
*   specifying a data set as well as x and y axis variables separately.       *
* Parameters:                                                                 *
*   Required:                                                                 * 
*     dsn      data set name                                                  *
*     vars     list of variables for inclusion on the x axis                  *
*     withvars list of variables for inclusion on the y axis                  *
*   Optional:                                                                 *
*     none                                                                    *
* Examples:                                                                   *
*   %correlation_heatmap(dsn=sashelp.baseball,                                *
*                        vars=nAtBat logSalary,                               *
*                        withvars=nHits nHome YrMajor);                       *
* Sub-macros called:                                                          *
*   %colormac built-in SAS macro to load the %hls macro                       *
* Data sets created:                                                          *
*   none                                                                      *
* History:                                                                    *
*   2021-08-08 Initial version.                                               *
************************************************** https://roelab.wustl.edu **/

%macro correlation_heatmap(dsn=,vars=,withvars=);

/*
Load built-in sas color macros.
*/
%colormac;

/*
Create data set mapping correlation values to shades of green.
*/
data correlation_heatmap_rattrmap;
  retain id "myid";
  %do i=-100 %to 99;
    %let min=%sysevalf(&i./100);
    %let max=%sysevalf((&i.+1)/100);
    %let lightness=%sysfunc(abs(&i.));
	* linear map f(0)=5, f(100)=100 to avoid overly dark colors;
	%let lightness=%sysevalf(5+(100-5)/100*&lightness.);
	* reverse map f(0)=100, f(100)=5 so bigger correlations are darker;
	%let lightness=%sysevalf(105-&lightness.);
    min=&min;
    max=&max;
    color="%hls(240,&lightness,100)";
    altcolor="%hls(240,&lightness,100)";
    output;
  %end;
run;

/*
Transform the vars and withvars arguments into space-delimited, quoted strings 
named varsq and withvarsq for later use. This allows the macro to be called 
with less typing and similarly to elsewhere when variable lists are specified.
*/
%let sep = %str(" ");
%let varsq="%sysfunc(tranwrd(%cmpres(&vars),%str( ),&sep))";
%let withvarsq="%sysfunc(tranwrd(%cmpres(&withvars),%str( ),&sep))";

/* 
The fisher option of proc corr produces a correlation table in long format 
where each row represents a single correlation. Output this table for later 
processing via the output delivery system.
*/
proc corr data=&dsn. fisher;
ods output
  fisherpearsoncorr  = correlation_heatmap_1;
run;

/*
Swap the Var and WithVar values for later processing.
*/
data correlation_heatmap_2;
set correlation_heatmap_1;
tmp = WithVar;
WithVar = Var;
Var = tmp;
drop tmp;
run;

/*
Stack the original and swapped data sets on top of each other vertically. This 
will make selecting correlations for the heatmap easier so that one is not 
limited to including a given variable in either the x or y axes. Then filter 
the double-stacked, long-format correlation table to select only those 
correlations we wish to display in the heatmap.
*/
data correlation_heatmap;
set correlation_heatmap_1 correlation_heatmap_2;
if Var in (&varsq) and WithVar in (&withvarsq) then output;
run;

/*
Construct the correlation heatmap using proc sgplot. Drop rattrmap and rattrid 
options to use default color scale.
*/
ods graphics / width=640 height=400px;
title "Correlation Heat Map";
title2 "Continuous Color Ramp and Legend";
proc sgplot data=correlation_heatmap rattrmap=correlation_heatmap_rattrmap;
   heatmapparm x=Var y=WithVar colorresponse=Corr / 
     outline discretex rattrid=myid;
   text x=Var y=WithVar text=pValue / textattrs=(size=12pt) strip;
   gradlegend;
run;

/*
Clean up.
*/
proc datasets noprint;
delete correlation_heatmap_rattrmap 
       correlation_heatmap_1 
       correlation_heatmap_2 
       correlation_heatmap;
run;
quit;

%mend correlation_heatmap;
