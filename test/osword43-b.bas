REM Test OSWORD &43 saving.
REM
REM Before:
REM - 6502 second processor must not be in use.
REM - We must have sideways RAM in test_bank.
REM - Ideally test_bank should contain a recognisable ROM.
REM
REM After:
REM - "CHUNK" should be the contents of test_bank from test_start to test_start+test_length
REM
REM The above behaviour has been confirmed on an emulated Master 128.
REM IBOS 1.20 fails this test; it saves only buffer_size bytes, although it does
REM (not checked thoroughly) seem to be saving from the correct location in
REM the correct bank.

test_bank=4
test_start=&A000
test_length=&B00
buffer_size=&400

REM We disallow second processor to avoid the need to poke the filename into
REM the I/O processor and to avoid the bug demonstrated by osword43-a.bas.
IF PAGE<&E00 THEN PRINT "This test shouldn't be used on a second processor.":END

DIM buffer% buffer_size
DIM block% 256
DIM filename% 16
$filename%="CHUNK"

block%?0=&00:REM save from absolute address
block%!1=filename%
block%?3=test_bank
block%!4=test_start:REM sideways start address
block%!6=test_length
block%!8=buffer%
block%!10=buffer_size
A%=&43:X%=block%:Y%=block% DIV 256:CALL &FFF1
END
