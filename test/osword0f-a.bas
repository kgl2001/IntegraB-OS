REM Test using OSWORD &0F to set the time.
REM
REM This passes on a Master 128 running MOS 3.23 in b-em.

DIM block% 256

REM To make sure the time set call doesn't change the date, we record it before
REM doing anything. (This might fail if the test is run just before midnight,
REM but I don't think it's worth the complexity of handling that.)
block%?0=0
A%=&E:X%=block%:Y%=block% DIV 256:CALL &FFF1
orig_date$=LEFT$($block%,15)

FOR hour%=0 TO 23
FOR minute%=0 TO 59
PRINT "Testing ";FNpad(hour%);":";FNpad(minute%);"..."
FOR second%=0 TO 59
REM Set the time...
block%?0=8
set_time$=FNpad(hour%)+":"+FNpad(minute%)+":"+FNpad(second%)
set_offset%=(hour%*60+minute%)*60+second%
$(block%+1)=set_time$
A%=&F:X%=block%:Y%=block% DIV 256:CALL &FFF1
REM ... and then read the current time.
block%?0=0
A%=&E:X%=block%:Y%=block% DIV 256:CALL &FFF1
REM Because the clock might tick over to the next second between setting and
REM reading, we don't compare the strings - we compare "seconds since midnight"
REM and allow for a small mismatch.
read_time$=$(block%+16)
read_offset%=(VAL(LEFT$(read_time$,2))*60+VAL(MID$(read_time$,4,2)))*60+VAL(RIGHT$(read_time$,2))
IF read_offset%<set_offset% THEN read_offset%=read_offset%+24*60*60
IF read_offset%-set_offset%>1 THEN PRINT "Error! Set ";set_time$;", read ";read_time$:END
REM Unless we're close to midnight and the date might roll over, check the date
REM is unaltered.
IF read_offset%<((23*60+59)*60) AND LEFT$($block%,15)<>orig_date$ THEN PRINT "Error! Date was ";orig_date$;", now ";LEFT$($block%,15):END
NEXT
NEXT
NEXT
END

DEF FNpad(n%)=RIGHT$("00"+STR$(n%),2)
