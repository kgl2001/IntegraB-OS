REM Test the (undocumented?) OSWORD &49 operations &6A and &6B to convert
REM between day numbers and day/month/year formats.
REM
REM In IBOS 1.20, &6B (day number->day/month/year) appears to work up to but
REM not including 07/06/2079, which would be day number 65536, so this is just
REM a question of running out of day numbers with our 16-bit word.
REM
REM However, IBOS 1.20 &6A (day/month/year->day number) appears buggy; it
REM fails immediately for 01/01/1900. If the TYA just after LA823 is changed
REM to TXA, this operation works for the first few years, although it still
REM fails on 01/01/1904.
REM
REM Since these calls seem to be undocumented, it's not possible to say with
REM certainty this is a bug, but it seems natural to me that these operations
REM are intended to be each other's inverses.

REM Set this to TRUE to allow IBOS 1.20 operation &6B to be tested without the
REM bugs in &6A causing an early termination.
skip_known_bug=FALSE

DIM days_in_month_array(12)
FOR month=1 TO 12:READ days_in_month_array(month):NEXT

DIM block 256
day_of_month=1
month=1
year=1900
true_day_number=0
true_day_of_week=2:REM Monday
leap_year=FALSE
days_in_month=days_in_month_array(month)
PRINT
REPEAT
VDU 11
PRINT ;day_of_month;"/";month;"/";year;"            "

REM Convert day number into day-of-month/month/year
PROCclear_block
block?0=&6B
block?4=true_day_number MOD 256
block?5=true_day_number DIV 256
A%=&49:X%=block:Y%=block DIV 256:CALL &FFF1
IF block?8<>year DIV 100 THEN PRINT "Wrong century":END
IF block?9<>year MOD 100 THEN PRINT "Wrong year":END
IF block?10<>month THEN PRINT "Wrong month":END
IF block?11<>day_of_month THEN PRINT "Wrong day of month":END
IF block?12<>true_day_of_week THEN PRINT "Wrong day of week":END

IF skip_known_bug THEN GOTO 1000

REM Convert day_of_month/month/year into a day number
PROCclear_block
block?0=&6A
block?8=year DIV 100
block?9=year MOD 100
block?10=month
block?11=day_of_month
A%=&49:X%=block:Y%=block DIV 256:CALL &FFF1
IF block?0<>0 THEN PRINT "Date->day number conversion failed":END
day_number=block?4+256*block?5
IF day_number<>true_day_number THEN PRINT "Date->day number conversion returned incorrect value":END

1000PROCnext_day
UNTIL year=2100
END

REM Used to avoid things seeming to work because they're still correctly set
REM up by chance.
DEF PROCclear_block
block!0=0:block!4=0:block!8=0:block!12=0
ENDPROC

DEF PROCnext_day
true_day_number=true_day_number+1
true_day_of_week=(true_day_of_week MOD 7)+1
day_of_month=day_of_month+1
IF day_of_month<=days_in_month THEN ENDPROC
day_of_month=1
month=(month MOD 12)+1
days_in_month=days_in_month_array(month)
IF month=2 AND leap_year THEN days_in_month=days_in_month+1
IF month>1 THEN ENDPROC
year=year+1:leap_year=((year MOD 4)=0)
ENDPROC

DATA 31:REM January
DATA 28:REM February
DATA 31:REM March
DATA 30:REM April
DATA 31:REM May
DATA 30:REM June
DATA 31:REM July
DATA 31:REM August
DATA 30:REM September
DATA 31:REM October
DATA 30:REM November
DATA 31:REM December
