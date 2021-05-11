REM Test OSWRSC
REM
REM This copies the video data for a string from screen memory, then writes it
REM (in reverse video, to show it's not the same video data somehow being
REM preserved in screen memory) in both shadow and non-shadow modes using
REM OSWRSC.
REM
REM This works fine on IBOS 1.20.

*SHADOW 1
MODE 0
PROCassert(HIMEM=&3000)
test$="Hello, world!"
size=LEN(test$)*8
DIM block size
PRINT test$;
FOR I%=0 TO size-1:I%?block=I%?&3000:NEXT
FOR M%=128 TO 0 STEP -128
MODE M%
IF M%=128 THEN PROCassert(HIMEM=&8000) ELSE PROCassert(HIMEM=&3000)
?&D6=&00:?&D7=&30:Y%=0
FOR I%=0 TO size-1
A%=I%?block EOR 255:CALL &FFB3
IF (I% MOD 3)=0 AND Y%<255 THEN Y%=Y%+1:NEXT
?&D6=1+?&D6
IF ?&D6=0 THEN ?&D7=1+?&D7
NEXT
PRINTTAB(0,1);
IF M%=128 THEN PRINT "Press SPACE...";:OSCLI "FX21":REPEAT UNTIL GET=32
NEXT
END
DEF PROCassert(b)
IF NOT b THEN PRINT "Assertion failed":END
ENDPROC
