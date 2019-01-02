/********************************************************************************************************
Filename: TOOLS_FreqSelect_****_****.sas
Written by: Patrick Thompson 
Initial Creation Date: 01/02/2019
Revision Date: In Filename

This SAS Code is designed as a tool to run a n*n frequency for many variables in a dataset.

Specifically, this program is designed to do the following:

1. Create a frequency dataset for one variable against a list of many variables in a dataset
2. Combine all of the frequency datasets into a single dataset

INSTRUCTIONS

1. Follow the steps in the SET UP code block
2. Run the VARLIST query code and visually confirm that the variables listed are the variables that you would like to view
3. Execute the entire code file 
4. Review results dataset (prefix of Freq_)

********************************************************************************************************/

/*////////////////////////////////////////*/
/*////////////////////////////////////////*/
/*//////////////// SET UP ////////////////*/
/*////////////////////////////////////////*/
/*////////////////////////////////////////*/

/*STEP 1. INDICATE THE SOURCE LIBRARY AND DATASET FROM WHICH YOU WOULD LIKE TO RUN YOUR FREQUENCIES*/
%LET SOURCELIBRARY = WORK;
%LET SOURCEDATA = MASTER;
/*STEP 2. INDICATE THE PRIMARY COMPARISON VARIABLE, WHICH WILL BE CREATED AS COLUMNS IN THE DATASET*/
%LET COMPAREVAR = ProviderGeneral;

/*STEP 3. IF YOU WOULD ONLY LIKE TO INCLUDE A SUBSET OF VARIABLES IN YOUR FREQUENCY, MARK THIS AS 1.  OTHERWISE ENTER 0.*/
%LET USE_INCLUDESET = 0;
/*STEP 4. IF YOU WOULD ONLY LIKE TO INCLUDE A SMALL SUBSET OF VARIABLES IN YOUR SET, MARK THIS AS 1.  OTHERWISE ENTER 0.*/
%LET USE_EXCLUDESET = 0;

/*STEP 5. IF YOU HAVE MARKED USE_INCLUDESET AS 1, CREATE A LIST OF VARIABLES THAT YOU WOULD LIKE TO INCLUDE IN THE DATASET BELOW.*/
DATA INCLUDESET;
LENGTH VARNAME $100. ;
INPUT VARNAME $;
DATALINES;
Q1
ProviderGeneral
RUN;

/*STEP 6. IF YOU HAVE MARKED USE_EXCLUDESET AS 1, CREATE A LIST OF VARIABLES THAT YOU WOULD LIKE TO EXCLUDE IN THE DATASET BELOW.*/
DATA EXCLUDESET;
LENGTH VARNAME $100.;
INPUT VARNAME $;
DATALINES;
County
Encrypted_Ben_ID
EncryptedBeneficiaryID
ICO_Region
ID1
RUN;

/*STEP 7. RUN THE CODE BELOW, AND VIEW THE RESULTING VARLIST DATASET.  THESE ARE THE VARIABLES FOR WHICH WE WILL RUN THE FREQUENCY.  REPEAT UNTIL SATISFIED.*/
PROC SQL;
CREATE TABLE VARLIST AS
SELECT 	TRANWRD(LABEL, '''', '') AS LABEL
		, COLS.*
		, FORMATSET.FORMATNAME
		, EXCLUDESET.VARNAME AS EXC_VAR
		, INCLUDESET.VARNAME AS INC_VAR 
FROM DICTIONARY.COLUMNS COLS
LEFT JOIN FORMATSET ON FORMATSET.VARNAME = COLS.NAME
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

%MACRO FREQ_SELECT(NAME, NEWTYPE, FORMAT); 

PROC SORT DATA = MASTER; BY &NAME ; RUN;

PROC FREQ DATA = MASTER NOPRINT;
TABLES &NAME / OUT=TMP_%STR(&NAME) MISSING;
%IF &FORMAT NE . %THEN %DO;
FORMAT &NAME %STR(&FORMAT).;
%END;
RUN;

%IF &NEWTYPE=num %THEN %DO;
DATA TMP_%STR(&NAME);
FORMAT RESPONSE $4000.;
SET TMP_%STR(&NAME);
RESPONSE = PUT(&NAME, 12.);
DROP &NAME;
RUN;
%END;
%ELSE %DO;
DATA TMP_%STR(&NAME);
FORMAT RESPONSE $4000.;
SET TMP_%STR(&NAME);
RESPONSE = &NAME;
DROP &NAME;
RUN;
%END;

PROC SORT DATA = MASTER; BY %STR(&COMPAREVAR) &NAME ; RUN;

PROC FREQ DATA = MASTER NOPRINT;
TABLES &NAME / OUT= TMP_%STR(&NAME)_%STR(&COMPAREVAR) MISSING;
BY %STR(&COMPAREVAR);
%IF &FORMAT NE . %THEN %DO;
FORMAT &NAME %STR(&FORMAT).;
%END;
RUN;

PROC SORT DATA = TMP_%STR(&NAME)_%STR(&COMPAREVAR); BY &NAME %STR(&COMPAREVAR) COUNT; RUN;

PROC TRANSPOSE DATA=TMP_%STR(&NAME)_%STR(&COMPAREVAR) OUT=TMP_%STR(&NAME)_WIDE PREFIX=%STR(&COMPAREVAR)_ ;
BY &NAME;
ID %STR(&COMPAREVAR);
VAR COUNT;
RUN;

%IF &NEWTYPE=num %THEN %DO;

DATA TMP_%STR(&NAME)_WIDE;
FORMAT RESPONSE $4000.;
SET TMP_%STR(&NAME)_WIDE;
RESPONSE = PUT(&NAME, 12.);
DROP &NAME;
RUN;
%END;

%else %DO;
DATA TMP_%STR(&NAME)_WIDE;
FORMAT RESPONSE $4000.;
SET TMP_%STR(&NAME)_WIDE;
RESPONSE = &NAME;
DROP &NAME;
RUN;
%END;

PROC SQL NOPRINT;
CREATE TABLE TMP_%STR(&NAME)_NEW AS
SELECT TMP_%STR(&NAME)_WIDE.*
	, TMP_%STR(&NAME).COUNT
	, TMP_%STR(&NAME).COUNT AS TOTAL 
	, TMP_%STR(&NAME).PERCENT AS PERCENT
FROM TMP_%STR(&NAME)_WIDE
LEFT JOIN TMP_%STR(&NAME) ON TMP_%STR(&NAME).RESPONSE = TMP_%STR(&NAME)_WIDE.RESPONSE;
%STR(QUIT;);

DATA RES_%STR(&NAME)_NEW;
FIELD = "&NAME";
SET TMP_%STR(&NAME)_NEW(DROP=_NAME_ _LABEL_); 
RESPONSE=STRIP(RESPONSE);
RUN;
%MEND;


DATA VARLIST;
SET VARLIST;
CALL EXECUTE('%FREQ_SELECT('|| STRIP(NAME) || ', ' || STRIP(TYPE) ||', ' || FORMATNAME || ');');
RUN;

PROC SQL NOPRINT;
SELECT MEMNAME INTO: MYVAR SEPARATED BY ' ' FROM DICTIONARY.TABLES
WHERE LIBNAME = 'WORK'
AND MEMNAME LIKE 'RES_%';
QUIT;

DATA FREQ_&COMPAREVAR;
SET &MYVAR;
RUN;

PROC SQL NOPRINT;
SELECT MEMNAME INTO: MYVAR SEPARATED BY ' ' FROM DICTIONARY.TABLES
WHERE LIBNAME = 'WORK'
AND (MEMNAME LIKE 'TMP%' OR MEMNAME LIKE 'RES%');
QUIT;


PROC DATASETS LIB=WORK NOPRINT;
DELETE &MYVAR;
DELETE INCLUDESET;
DELETE EXCLUDESET;
DELETE VARLIST;
QUIT;

