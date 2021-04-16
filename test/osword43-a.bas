REM Test OSWORD &43 filename is taken from host RAM not parasite RAM
REM
REM Before:
REM - 6502 second processor must be in use.
REM - We must have sideways RAM in test_bank; it will be corrupted.
REM - Ideally test_bank should be empty to avoid confusion.
REM
REM After:
REM - ROMA should be loaded into test_bank, *not* ROMB. (Press CTRL-BREAK
REM   and use *ROMS to check this; the test roms don't show in *HELP.)
REM
REM The above behaviour has been confirmed on an emulated Master 128.
REM IBOS 1.20 fails this test; it loads ROMB.

test_bank=4

MODE 7
IF PAGE<>&800 THEN PRINT "This test needs a second processor.":END

REM This address is OK in the host and parasite; note we selected mode 7 above.
filename_address=&3000

DIM block% 256
f$="ROMA"+CHR$(13):FOR I%=1 TO LEN(f$):PROCwrite_io(filename_address+I%-1,ASC(MID$(f$,I%,1))):NEXT
$filename_address="ROMB"

block%?0=&80:REM write to absolute address
block%!1=filename_address
block%?3=test_bank
block%!4=&8000:REM sideways start address
block%!6=&EAEA:REM ignored, but let's be predictable
block%!8=0:REM buffer address
block%!10=0:REM buffer length; 0 => use private workspace
A%=&43:X%=block%:Y%=block% DIV 256:CALL &FFF1
END

REM http://beebwiki.mdfs.net/OSWORD_%2606
DEF PROCwrite_io(addr,byte)
!block%=addr:block%?4=byte
A%=6:X%=block%:Y%=block% DIV 256:CALL &FFF1
ENDPROC
