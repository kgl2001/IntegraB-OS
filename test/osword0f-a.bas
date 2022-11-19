REM Test using OSWORD &0F to set the time.

DIM block% 256

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
NEXT
NEXT
NEXT
END

DEF FNpad(n%)=RIGHT$("00"+STR$(n%),2)
