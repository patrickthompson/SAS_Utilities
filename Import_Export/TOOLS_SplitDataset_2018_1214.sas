/********************************************************************************************************
Filename: TOOLS_SplitDataset_****_****.sas
Written by: Patrick Thompson 
Initial Creation Date: 11/28/2018
Revision Date: In Filename

This SAS Code is designed as a tool to split tall datasets into many shorter sets. 

Specifically, this program is designed to do the following:

1. Piece the datasets into the size that are indicated
2. Save the files based on either a SAS or CSV format (or both)

INSTRUCTIONS

1. Follow the steps in the SET UP code block
2. Indicate the file format that you would like the saved file to follow
3. Execute the code 
4. Review results dataset

********************************************************************************************************/

/*////////////////////////////////////////*/
/*////////////////////////////////////////*/
/*//////////////// SET UP ////////////////*/
/*////////////////////////////////////////*/
/*////////////////////////////////////////*/

/*STEP 1. NAME THE TABLE THAT YOU WOULD LIKE TO SPLIT*/
/*(NOTE: YOU CAN ADD A LIBRARY BY LISTING IT BEFORE THE TABLE NAME, LIKE WORK.TABLE_NAME)*/
%LET TABLENAME = MYTABLENAME;

/*STEP 2. HOW MANY RECORDS WOULD YOU LIKE IN EACH DATASET?*/
%LET NUM_RECORDS_SPLIT = 100000;

/*STEP 3. WHAT PREFIX WOULD YOU LIKE TO USE FOR THE FILE NAME OF EACH DATASET?*/
%LET SAVE_PREFIX = MYPREFIX;

/*STEP 4. CREATE A COMMA SEPARATED LIST OF THE VARIABLES THAT YOU WOULD LIKE TO SELECT*/
/*(NOTE: IF YOU WOULD LIKE TO SELECT ALL COLUMNS, JUST USE AN ASTERISK * )*/
%LET SELECT_STRING = *;

/*//////////////////////////////////////////////////*/
/*//////////////////////////////////////////////////*/
/*//////////////// SAVE FILE FORMAT ////////////////*/
/*//////////////////////////////////////////////////*/
/*//////////////////////////////////////////////////*/

/*/////////////////////////////////////////////*/
/*//////////////// SAVE AS CSV ////////////////*/
/*/////////////////////////////////////////////*/

/*SWITCH THIS TO 1 IF YOU WANT TO SAVE THE FILES AS CSV FILES*/
%LET SAVE_CSV = 1;
/*IF YOU SAVE AS CSV, YOU MUST INDICATE A DRIVE LOCATION WHERE YOU WOULD LIKE TO SAVE THE FILES*/
%LET SAVE_LOCATION = D:\

/*///////////////////////////////////////////////////////*/
/*//////////////// SAVE AS A SAS DATASET ////////////////*/
/*///////////////////////////////////////////////////////*/

/*SWITCH THIS TO 1 IF YOU WANT TO SAVE THE FILES AS SAS FILES*/
%LET SAVE_SAS = 0;
/*IF YOU SAVE AS A SAS FILE, YOU MUST INDICATE A LIBRARY WHERE YOU WOULD LIKE TO SAVE THE FILES*/
%LET SAVE_LIBNAME = WORK;

/*///////////////////////////////////////////////////////*/
/*///////////////////////////////////////////////////////*/
/*///////////////////////////////////////////////////////*/
/*//////////////// YOU'RE DONE! HIT RUN ////////////////*/
/*///////////////////////////////////////////////////////*/
/*///////////////////////////////////////////////////////*/
/*///////////////////////////////////////////////////////*/

RUN;
/*//////////////////////////////////////////////////*/
/*//////////////////////////////////////////////////*/
/*//////////////// BEGIN PROCESSING ////////////////*/
/*//////////////////////////////////////////////////*/
/*//////////////////////////////////////////////////*/

PROC SQL NOPRINT;
SELECT COUNT(*) INTO :TOTALROWS FROM &TABLENAME;
QUIT;

%LET NUMBER_OF_LOOPS = %SYSEVALF(&TOTALROWS / &NUM_RECORDS_SPLIT, CEIL);

%MACRO CREATE_SAS(COUNTER, ROWVAL);

PROC SQL;
CREATE TABLE %STR(&SAVE_LIBNAME).%STR(&SAVE_PREFIX)_%STR(&COUNTER) AS
SELECT * FROM 
(SELECT MONOTONIC() AS RNUM, &SELECT_STRING FROM %STR(&TABLENAME)) P
WHERE RNUM > &ROWVAL
AND RNUM <= (&ROWVAL + &NUM_RECORDS_SPLIT);
%STR(QUIT;);

DATA %STR(&SAVE_LIBNAME).%STR(&SAVE_PREFIX)_%STR(&COUNTER);
SET %STR(&SAVE_LIBNAME).%STR(&SAVE_PREFIX)_%STR(&COUNTER) (DROP=RNUM);
RUN;

%MEND;

%MACRO CREATE_CSV(COUNTER, ROWVAL);

PROC SQL;
CREATE TABLE %STR(&SAVE_PREFIX)_%STR(&COUNTER) AS
SELECT * FROM 
(SELECT MONOTONIC() AS RNUM, &SELECT_STRING FROM %STR(&TABLENAME)) P
WHERE RNUM > &ROWVAL
AND RNUM <= (&ROWVAL + &NUM_RECORDS_SPLIT);
%STR(QUIT;);

DATA %STR(&SAVE_PREFIX)_%STR(&COUNTER);
SET %STR(&SAVE_PREFIX)_%STR(&COUNTER) (DROP=RNUM);
RUN;

proc export data=%STR(&SAVE_PREFIX)_%STR(&COUNTER)
   outfile="%STR(&SAVE_LOCATION)%STR(&SAVE_PREFIX)_%STR(&COUNTER).csv"
   dbms=csv
   replace;
run;

PROC DATASETS LIB=WORK NOPRINT;
DELETE %STR(&SAVE_PREFIX)_%STR(&COUNTER);
%STR(QUIT;);

%MEND;


data resultset;
FORMAT FORMATROW $2.;
MINROWVAR = 0;

do i = 1 to &NUMBER_OF_LOOPS;
	new_i = 'length=' ||  put(i,z3.);
	put  new_i;
	IF &SAVE_SAS = 1 THEN DO;
		CALL EXECUTE('%CREATE_SAS('|| put(i,z3.) || ',' ||MINROWVAR||');');
	END;
	IF &SAVE_CSV = 1 THEN DO;
		CALL EXECUTE('%CREATE_CSV('|| put(i,z3.) || ',' || MINROWVAR||');');
	END;
	MINROWVAR = MINROWVAR + &NUM_RECORDS_SPLIT;
  end;
run;
