REM Test using OSWORD &0F to set the time and date.
REM
REM TODO: NOT CHECKED YET This passes on a Master 128 running MOS 3.23 in b-em.

DIM day_of_week$(6)
FOR I%=0 TO 6:READ day_of_week$(I%):NEXT
DATA Sun,Mon,Tue,Wed,Thu,Fri,Sat

DIM month$(12)
FOR I%=1 TO 12:READ month$(I%):NEXT
DATA Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec

DIM month_length%(12)
FOR I%=1 TO 12:READ month_length%(I%):NEXT
DATA 31,28,31,30,31,30,31,31,30,31,30,31

DIM block% 256

REM TODO: If we ignored the century when testing the value read back, we'd probably pass OK on Master OS 3.20 and 3.23.
day_of_week%=6:REM Saturday
FOR year%=2000 TO 2099
FOR month%=1 TO 12
IF month%=2 AND (year% MOD 4)=0 THEN days_in_month%=29 ELSE days_in_month%=month_length%(month%)
FOR day%=1 TO days_in_month%
PRINT "Testing ";year%;"/";FNpad(month%);"/";FNpad(day%);"..."
FOR hour%=0 TO 23 STEP 5
FOR minute%=0 TO 55 STEP 5
second%=(hour%+minute%) MOD 60
set_time$=day_of_week$(day_of_week%)+","+FNpad(day%)+" "+month$(month%)+" "+STR$(year%)+"."+FNpad(hour%)+":"+FNpad(minute%)+":"+FNpad(second%)
REM Set the date/time...
block%?0=24
set_offset%=(hour%*60+minute%)*60+second%
$(block%+1)=set_time$
A%=&F:X%=block%:Y%=block% DIV 256:CALL &FFF1
REM ... and then read the current date/time.
block%?0=0
A%=&E:X%=block%:Y%=block% DIV 256:CALL &FFF1
REM Because the clock might tick over to the next second between setting and
REM reading, we don't compare the strings - we compare "seconds since midnight"
REM and allow for a small mismatch.
read_date_time$=$block%
read_time$=RIGHT$(read_date_time$,8)
read_offset%=(VAL(LEFT$(read_time$,2))*60+VAL(MID$(read_time$,4,2)))*60+VAL(RIGHT$(read_time$,2))
IF read_offset%<set_offset% THEN read_offset%=read_offset%+24*60*60
IF read_offset%-set_offset%>1 THEN PRINT "Error! Set ";set_time$;", read ";read_date_time$:END
read_dow$=LEFT$(read_date_time$,3)
IF read_dow$<>day_of_week$(day_of_week%) THEN PRINT "Error! Set ";set_time$;" which is ";day_of_week$(day_of_week%);" but read ";read_date_time$:END
IF VAL(MID$(read_date_time$,5,2))<>day% THEN PRINT "Error! Set ";set_time$;", read ";read_date_time$:END
IF MID$(read_date_time$,8,3)<>month$(month%) THEN PRINT "Error! Set ";set_time$;", read ";read_date_time$:END
IF VAL(MID$(read_date_time$,12,4))<>year% THEN PRINT "Error! Set ";set_time$;", read ";read_date_time$:END
NEXT
NEXT
day_of_week%=(day_of_week%+1) MOD 7
NEXT
NEXT
NEXT
END

DEF FNpad(n%)=RIGHT$("00"+STR$(n%),2)
