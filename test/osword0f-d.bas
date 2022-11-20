REM Test using OSWORD &0F to set the time and date just before midnight doesn't
REM fail.
REM
REM TODO: NOT CHECKED YET This passes on a Master 128 running MOS 3.23 in b-em.

DIM block% 256

PRINT "This test runs forever unless it detects a failure..."
pass%=0
REPEAT
block%?0=24
$(block%+1)="Sat,05 Nov 2022.23:59:59"
A%=&F:X%=block%:Y%=block% DIV 256:CALL &FFF1
T%=TIME:REPEAT UNTIL TIME-T%>=200
block%?0=0
A%=&E:X%=block%:Y%=block% DIV 256:CALL &FFF1
time$=$block%
IF LEFT$(time$,15)<>"Sun,06 Nov 2022" THEN PRINT "Error; time is ";time$:END
offset%=(VAL(LEFT$(time$,2))*60+VAL(MID$(time$,4,2)))*60+VAL(RIGHT$(time$,2))
IF offset%>=3 THEN PRINT "Error; time is ";time$:END
pass%=pass%+1
IF (pass% MOD 100)=0 THEN PRINT "Pass ";pass%;" completed..."
UNTIL FALSE
