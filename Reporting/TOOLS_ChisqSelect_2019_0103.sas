
/********************************************************************************************************
Filename: TOOLS_ChisqSelect_****_****.sas
Written by: Patrick Thompson 
Initial Creation Date: 01/03/2019
Revision Date: In Filename

This SAS Code is designed as a tool to run 1*n chisquare statistic for all variables in a subset.

Specifically, this program is designed to do the following:

1. Create a dataset of chisquare statistic results for one variable against a list of many variables in a dataset
2. Combine all of the result datasets into a single dataset
3. Sort the result set by the lowest p-values

INSTRUCTIONS

1. Follow the steps in the SET UP code block
2. Run the VARLIST query code and visually confirm that the variables listed are the variables that you would like to view
3. Execute the entire code file 
4. Review results dataset (prefix of CHISQ_)

********************************************************************************************************/

/*////////////////////////////////////////*/
/*////////////////////////////////////////*/
/*//////////////// SET UP ////////////////*/
/*////////////////////////////////////////*/
/*////////////////////////////////////////*/

/*STEP 1. INDICATE THE SOURCE LIBRARY AND DATASET FROM WHICH YOU WOULD LIKE TO RUN YOUR FREQUENCIES*/
%LET SOURCELIBRARY = WORK;
%LET SOURCEDATA = MASTER;
/*STEP 2. INDICATE THE PRIMARY COMPARISON VARIABLE FOR ALL CHISQUARE TESTS*/
%LET COMPAREVAR = MyVariableName;

/*STEP 3. IF YOU WOULD ONLY LIKE TO INCLUDE A SUBSET OF VARIABLES IN YOUR FREQUENCY, MARK THIS AS 1.  OTHERWISE ENTER 0.*/
%LET USE_INCLUDESET = 0;
/*STEP 4. IF YOU WOULD ONLY LIKE TO INCLUDE A SMALL SUBSET OF VARIABLES IN YOUR SET, MARK THIS AS 1.  OTHERWISE ENTER 0.*/
%LET USE_EXCLUDESET = 0;

/*STEP 5. IF YOU HAVE MARKED USE_INCLUDESET AS 1, CREATE A LIST OF VARIABLES THAT YOU WOULD LIKE TO INCLUDE IN THE DATASET BELOW.*/
DATA INCLUDESET;
LENGTH VARNAME $8. ;
INPUT VARNAME $;
DATALINES;
Var1
RUN;

/*STEP 6. IF YOU HAVE MARKED USE_EXCLUDESET AS 1, CREATE A LIST OF VARIABLES THAT YOU WOULD LIKE TO EXCLUDE IN THE DATASET BELOW.*/
DATA EXCLUDESET;
LENGTH VARNAME $100.;
INPUT VARNAME $;
DATALINES;
Var2
RUN;

/*STEP 7. RUN THE CODE BELOW, AND VIEW THE RESULTING VARLIST DATASET.  THESE ARE THE VARIABLES FOR WHICH WE WILL RUN THE FREQUENCY.  REPEAT UNTIL SATISFIED.*/
PROC SQL;
CREATE TABLE VARLIST AS
SELECT 	TRANWRD(LABEL, '''', '') AS LABEL
		, COLS.*
		, EXCLUDESET.VARNAME AS EXC_VAR
		, INCLUDESET.VARNAME AS INC_VAR 
FROM DICTIONARY.COLUMNS COLS
LEFT JOIN EXCLUDESET 
	ON LOWER(EXCLUDESET.VARNAME) = LOWER(COLS.NAME)
LEFT JOIN INCLUDESET 
	ON LOWER(INCLUDESET.VARNAME) = LOWER(COLS.NAME)
WHERE 	LOWER(LIBNAME) = LOWER("&SOURCELIBRARY") 
		AND LOWER(MEMNAME) = LOWER("&SOURCEDATA")
		AND (EXCLUDESET.VARNAME IS NULL OR &USE_EXCLUDESET = 0)
		AND (INCLUDESET.VARNAME IS NOT NULL OR &USE_INCLUDESET = 0)
		AND LOWER(COLS.NAME) NE LOWER("&COMPAREVAR") ;
QUIT;


/*///////////////////////////////////////////////////////*/
/*///////////////////////////////////////////////////////*/
/*///////////////////////////////////////////////////////*/
/*//////////////// YOU'RE DONE! HIT RUN ////////////////*/
/*///////////////////////////////////////////////////////*/
/*///////////////////////////////////////////////////////*/
/*///////////////////////////////////////////////////////*/

/*//////////////////////////////////////////////////*/
/*//////////////////////////////////////////////////*/
/*//////////////// BEGIN PROCESSING ////////////////*/
/*//////////////////////////////////////////////////*/
/*//////////////////////////////////////////////////*/

%MACRO CHISQ_SELECT(TABLENAME, LABEL);
PROC FREQ DATA = &SOURCEDATA NOPRINT;
TABLE &COMPAREVAR*&TABLENAME/CHISQ;
output out=CHISQVAR_T_&TABLENAME pchi lrchi;
RUN;

PROC SQL NOPRINT;
CREATE TABLE CHISQVAR_R_&TABLENAME AS
SELECT '&TABLENAME' AS VARIABLE
, '&LABEL' AS LABEL LENGTH = 4000
, * FROM CHISQVAR_T_&TABLENAME;
QUIT;

%MEND;


DATA VARLIST;
SET VARLIST;
CALL EXECUTE("%CHISQ_SELECT("|| NAME || ", " || TRIM(LABEL) ||");");
RUN;

PROC SQL NOPRINT;
SELECT MEMNAME INTO: MYVAR SEPARATED BY ' ' FROM DICTIONARY.TABLES
WHERE LIBNAME = 'WORK'
AND MEMNAME LIKE 'CHISQVAR_R%';
QUIT;

DATA CHISQ_&COMPAREVAR;
SET &MYVAR;
RUN;

PROC SQL NOPRINT;
SELECT MEMNAME INTO: MYVAR SEPARATED BY ' ' FROM DICTIONARY.TABLES
WHERE LIBNAME = 'WORK'
AND MEMNAME LIKE 'CHISQVAR%';
QUIT;

PROC DATASETS LIBNAME=WORK NOPRINT;
DELETE &MYVAR;
DELETE INCLUDESET;
DELETE EXCLUDESET;
DELETE VARLIST;
QUIT;

PROC SORT DATA = CHISQ_&COMPAREVAR; BY P_PCHI; RUN;
