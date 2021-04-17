; Terminology:
; - "private RAM" is the 12K of RAM which can be paged in via PRVEN+PRVS1/4/8 in
;   the &8000-&BFFF region
; - "shadow RAM" is the 20K of RAM which can be paged in via SHEN+MEMSEL in the
;   &3000-&7FFF region

; SFTODO: The following constants and associated comments are a bit randomly ordered, this should be tidied up eventually.
; For example, it might help to move the comments about RTC register use nearer to the private memory allocations, as
; some of those are copies of each other.

;PRVS1 Address &81xx
;Used to store *BOOT parameters

;PRVS1 Address &82xx
;&09:
;&0A:
;&0B:
;&0C:
;&0D:
;&0E:
;&0F:

;used during osword &42 and &43 processing
;&20..&2F: Copy of osword &42 / &43 parameter block
;&30..&31: Copy of original osword parameter block location in memory

;&20:	&05
;&21:	&84
;&22:	&44
;&23:	&EB
;&24:
;&25:
;&26:
;&27:
;&28:	RTC &35 - Century
;&29:	RTC &09 - Year (Set at LA6CB)
;&2A:	RTC &08 - Month (Set at LA6CB)
;&2B:	RTC &07 - Day of Month (Set at LA6CB)
;&2C:	RTC &06 - Day of Week (Set at LA6CB)
;&2D:	RTC &04 - Hours (Set at LA676)
;&2E:	RTC &02 - Minutes (Set at LA676)
;&2F:	RTC &00 - Seconds (Set at LA676)
;&52:	
;&53:	

;PRVS1 Address &83xx
;&08..&0B - Stores the absolute RAM bank number for the Pseudo RAM banks W, X, Y, Z
;&0C..&0F - 
;&18..&1B - Used to store the RAM banks that are assigned to *BUFFER. Up to 4 RAM banks can be assigned. Set to &FF if nothing assigned. 
;&2C..&3B - Private RAM Copy of ROM Type
;3C - OSMODE ?


;RTC Clock Registers
;Register &00 - Seconds:	 	00
;Register &01 - Sec Alarm:	 	00
;Register &02 - Minutes:	 	00
;Register &03 - Min Alarm:	 	00
;Register &04 - Hours:		00
;Register &05 - Hr Alarm:	 	00
;Register &06 - Day of Week:		07 (Saturday)	Note: This was set to 2 (Mon), which was correct when century was 1900
;Register &07 - Day of Month:		01
;Register &08 - Month:		01 (January)
;Register &09 - Year:		00
;Register &0A
;Register &0B
;Register &0C
;Register &0D

rtcUserBase = &0E
;RTC User Registers (add &0E to get real RTC user register - registers &00-&0D are for RTC clock registers)
;Register &00
;Register &01
;Register &02
;Register &03
;Register &04
;Register &05
;Register &06 - &FF:	*INSERT status for ROMS &0F to &08. Default: &FF (All 8 ROMS enabled)
;Register &07 - &FF:	*INSERT status for ROMS &07 to &00. Default: &FF (All 8 ROMS enabled)
;Register &08
;Register &09
;Register &0A - &17:	0-2: MODE / 3: SHADOW / 4: TV Interlace / 5-7: TV screen shift
;Register &0B - &23:	0-2: FDRIVE / 3-5: CAPS
;Register &0C - &19:	0-7: Keyboard Delay
;Register &0D - &05:	0-7: Keyboard Repeat
;Register &0E - &0A:	0-7: Printer Ignore
;Register &0F - &2D:	0: Tube / 2-4: BAUD / 5-7: Printer
;Register &10 - &A0:	0: File system disc/net flag / 4: Boot / 5-7: Data


; These registers are held in private RAM at &83B2-&83FF; this is battery-backed
; (as is the whole of private and shadow RAM), so they look just like the above
; RTC user registers to code accessing them via readUserReg/writeUserReg.
;Register &32 - &04:	0-2: OSMODE / 3: SHX
;Register &35 - &13:	Century
;Register &38 - &FF:
;Register &39 - &FF:
;Register &3A - &90:
;Register &7F - &7F:	Bit set if RAM located in 32k bank. Default was &0F (lowest 4 x 32k banks). Changed to &7F

; These constants identify user registers for use with readUserReg/writeUserReg;
; although some of these will be stored in RTC user registers, this is really an
; implementation detail (and an offset of rtcUserBase needs to be applied when
; accessing them, which will be handled automatically by
; readUserReg/writeUserReg if necessary).
userRegDiscNetBootData = &10 ; 0: File system disc/net flag / 4: Boot / 5-7: Data
userRegOsModeShx = &32 ; b0-2: OSMODE / b3: SHX
userRegHorzTV = &36 ; "horizontal *TV" settings
userRegPrvPrintBufferStart = &3A ; the first page in private RAM reserved for the printer buffer (&90-&AC)

; SFTODO: Very temporary variable names, this transient workspace will have several different uses on different code paths. These are for osword 42, the names are short for my convenience in typing as I introduce them gradually but they should be tidied up later.
; SFTODO: I am thinking these names - maybe now, and probably also in "final" vsn - should have the actual address as part of the name - because different bits of code use the same location for different things, this will help to make it a bit more obvious if two bits of code are trying to use the same location for two different purposes at once (mainly important when we come to modify the code, but just might be relevant if there are bugs in the existing code)
transientOs4243SwrAddr = &A8 ; 2 bytes
transientOs4243MainAddr = &AA ; 2 bytes
; SFTODO: &AC/&AD IS USED FOR ANOTHER 16-BIT WORD, SEE adjustTransferParameters
transientOs4243BytesToTransfer = &AE ; 2 bytes
transientRomBankMask = &AE ; 2 bytes

transientCmdPtr = &A8 ; 2 bytes
transientTblPtr = &AA ; 2 bytes
transientConfIdx = &AA ; 1 byte
transientDynamicSyntaxState = &AE ; 1 byte
; SFTODO: Named constants for b7 and b6
transientDynamicSyntaxStateCountMask = %00111111

vduStatus = &D0
vduStatusShadow = &10
negativeVduQueueSize = &026A
tubePresenceFlag = &027A ; SFTODO: allmem says 0=inactive, is there actually a specific bit or value for active? what does this code rely on?
osShadowRamFlag = &027F ; *SHADOW option, 0=don't force shadow modes, 1=force shadow modes (note that AllMem.txt seems to have this wrong, at least my copy does)
currentMode = &0355

osCmdPtr = &F2

osfindClose = &00
osfindOpenInput = &40
osfindOpenOutput = &80
osgbpbReadCurPtr = &04
osfileReadInformation = &05
osfileReadInformationLengthOffset = &0A
osfileLoad = &FF

osbyteReadHimem = &84
osbyteReadWriteOshwm = &B4
osbyteIssueServiceRequest = &8F

romBinaryVersion = &8008

oswdbtA = &EF
oswdbtX = &F0
oswdbtY = &F1

CmdTblOffset = 6
CmdTblPtrOffset = 10

; This is a byte of unused CFS/RFS workspace which IBOS repurposes to track
; state during mode changes. This is probably done because it's quicker than
; paging in private RAM; OSWRCH is relatively performance sensitive and we check
; this on every call.
modeChangeState = &03A5
modeChangeStateNone = 0 ; no mode change in progress
modeChangeStateSeenVduSetMode = 1 ; we've seen VDU 22, we're waiting for mode byte
modeChangeStateEnteringShadowMode = 2 ; we're changing into a shadow mode
modeChangeStateEnteringNonShadowMode = 3 ; we're changing into a non-shadow mode

; This is part of CFS/RFS workspace which IBOS temporarily borrows; various different
; code templates are copied here for execution.
variableMainRamSubroutine = &03A7 ; SFTODO: POOR NAME
variableMainRamSubroutineMaxSize = &32 ; SFTODO: ASSERT ALL THE SUBROUTINES ARE SMALLER THAN THIS

; This is filing system workspace which IBOS borrows. SFTODO: I'm slightly
; surprised we get away with this. (Note that AllMem.txt shows how it's used for
; CFS/RFS, which are *probably* not the current filing system, but I believe this
; is workspace for the current filing system whatever that is.)
; SFTODO: Not sure about "transient" prefix, that's sort of for the &A8 block,
; but want to convey the transient-use-ness.
; SFTODO: Named constants for the 0/1/2 values?
transientConfigPrefix = &BD ; 0=none, 1="NO", 2="SH" - see parseNoSh

vduBell = 7
vduCr = 13
vduSetMode = 22

lastBreakType = &028D

serviceConfigure = &28
serviceStatus = &29

INSVH       = &022B
INSVL       = &022A
KEYVH       = &0229
KEYVL       = &0228
BYTEVH      = &020B
BYTEVL      = &020A
BRKVH       = &0203
BRKVL       = &0202

RESET       = &FFFC
OSCLI       = &FFF7
OSBYTE      = &FFF4
OSWORD      = &FFF1
OSWRCH      = &FFEE
OSNEWL      = &FFE7
OSASCI      = &FFE3
OSRDCH      = &FFE0
OSFILE      = &FFDD
OSARGS      = &FFDA
OSBGET      = &FFD7
OSBPUT      = &FFD4
OSGBPB      = &FFD1
OSFIND      = &FFCE
GSREAD      = &FFC5
GSINIT      = &FFC2
OSEVEN      = &FFBF
OSRDRM      = &FFB9
SHEILA      = &FE00

romsel = SHEILA + &30
romselCopy = &F4
ramsel = SHEILA + &34
ramselCopy = &037F ; unused VDU variable workspace repurposed by IBOS

tubeEntry = &0406
tubeEntryClaim = &C0 ; plus claim ID
tubeEntryRelease = &80 ; plus claim ID
; http://beebwiki.mdfs.net/Tube_Protocol says tube claimant ID &3F is allocated
; to "Language startup"; I suspect IBOS's use of this is technically wrong but
; as long as no one else is using it it will probably be fine, because we won't
; be trying to claim the tube while a language is starting up.
tubeClaimId = &3F

L0000       = &0000
L0032       = &0032
L006D       = &006D
L00A8       = &00A8
L00A9       = &00A9
L00AA       = &00AA
L00AB       = &00AB
L00AC       = &00AC
L00AD       = &00AD
L00AE       = &00AE
L00AF       = &00AF
L00B0       = &00B0
L00B1       = &00B1
L00B2       = &00B2
L00B3       = &00B3
L00B4       = &00B4
L00B5       = &00B5
L00B6       = &00B6
L00B7       = &00B7
L00B8       = &00B8
L00B9       = &00B9
L00BA       = &00BA
L00BB       = &00BB
L00BC       = &00BC
L00BD       = &00BD
L00D0       = &00D0
L00D6       = &00D6
L00EF       = &00EF
L00F0       = &00F0
L00F1       = &00F1
L00F2       = &00F2
L00F3       = &00F3
L00F6       = &00F6
L00F7       = &00F7
L00FA       = &00FA
L00FC       = &00FC
L00FD       = &00FD
L00FE       = &00FE
L00FF       = &00FF
L0100       = &0100
L0101       = &0101
L0102       = &0102
L0103       = &0103
L0104       = &0104
L0105       = &0105
L0106       = &0106
L0107       = &0107
L0108       = &0108
L0109       = &0109
L010B       = &010B
L010C       = &010C
L0113       = &0113
L024A       = &024A
L026A       = &026A
L027A       = &027A
L027F       = &027F
L0287       = &0287
L028C       = &028C
L028D       = &028D
L02A1       = &02A1
L02EE       = &02EE
L02EF       = &02EF
L02F0       = &02F0
L02F1       = &02F1
L02F2       = &02F2
L02F3       = &02F3
L02F4       = &02F4
L02F5       = &02F5
L02F6       = &02F6
L02F7       = &02F7
L02F8       = &02F8
L02F9       = &02F9
L02FA       = &02FA
L02FB       = &02FB
L02FC       = &02FC
L02FD       = &02FD
L02FE       = &02FE
L02FF       = &02FF
L0355       = &0355
L0380       = &0380
L0387       = &0387
L0388       = &0388
L0389       = &0389
L03A4       = &03A4
L03A5       = &03A5 ; SFTODO: This is an unused part of CFS/RFS workspace, IBOS seems to be using it  hold something across WRCHV calls but not sure - possibly it's to allow a quick check for shadow/non-shadow mode?
L03A7       = &03A7
L03B1       = &03B1
L03B2       = &03B2
L03B4       = &03B4
L03B5       = &03B5
L03B6       = &03B6
L03BB       = &03BB
L03BD       = &03BD
L03C1       = &03C1
L03C2       = &03C2
L03CB       = &03CB
L03D2       = &03D2
L03D3       = &03D3
L03D4       = &03D4
L03D6       = &03D6
L03D7       = &03D7
L0400       = &0400
L0406       = &0406
L0700       = &0700
L0880       = &0880
; The OS printer buffer is stolen for use by our code stub; we take over printer
; buffering responsibilities using our private RAM so the OS won't touch this
; memory.
osPrintBuf  = &0880 ; &0880-&08BF inclusive = &40 bytes bytes
L0895       = &0895
L089B       = &089B
L08AD       = &08AD
L08AE       = &08AE
L08AF       = &08AF
L08B1       = &08B1
L08B3       = &08B3
L08B5       = &08B5
L08B6       = &08B6
L0B00       = &0B00
L0B0A       = &0B0A
L0B10       = &0B10
L0C91       = &0C91
L0DBC       = &0DBC
L0DDD       = &0DDD
L0DF0       = &0DF0
L2800       = &2800
L285D       = &285D
L2874       = &2874
L2875       = &2875

prv80       = &8000
prv81       = &8100
prv82       = &8200
prv83       = &8300

; SFTODO: The following are grouped "logically" for now, rather than by address.
; This is probably easiest to understand, and if we're going to create a table
; showing all the addresses in order later on, there's no need for these labels
; to be in physical address order. SFTODO: Might actually be in physical order, I'll see how it works out.

; The printer buffer is implemented using two "extended pointers" - one for
; reading, one for writing. Each consists of a two byte address and a one byte
; index to a bank in prvPrintBufferBankList; note that these addresses are
; physical addresses in the &8000-&BFFF region, not logical offsets from the
; start of the printer buffer. The two pointers are adjacent in memory and some
; code (using prvPrintBufferPtrBase) will operate on either, using X to specify
; the read pointer (0) or the write pointer (3).
prvPrintBufferPtrBase = prv82 + &00
prvPrintBufferWritePtr = prv82 + &00
prvPrintBufferWriteBankIndex = prv82 + &02
prvPrintBufferReadPtr = prv82 + &03
prvPrintBufferReadBankIndex = prv82 + &05
; The printer buffer can be up to 64K in size; 64K is &10000 bytes so we need to
; use a 24-bit representation and we therefore have high, middle and low bytes
; here instead of just high and low bytes.
prvPrintBufferFreeLow   = prv82 + &06
prvPrintBufferFreeMid   = prv82 + &07
prvPrintBufferFreeHigh  = prv82 + &08
prvPrintBufferSizeLow   = prv82 + &09
prvPrintBufferSizeMid   = prv82 + &0A
prvPrintBufferSizeHigh  = prv82 + &0B
; prvPrintBufferBankStart is the high byte of the start address of the banks
; used for the printer buffer. This is &80 for sideways RAM, or a copy of
; prvPrvPrintBufferStart (&90-&AC) for private RAM.
prvPrintBufferBankStart = prv82 + &0C
; prvPrintBufferFirstBankIndex is used to initialise
; prvPrintBufferWriteBankIndex and prvPrintBufferReadBankIndex. SFTODO: I think
; this is always zero; if so it's redundant and there's no need to write it and
; we can just use 0 instead of reading it, which would save a few bytes of code.
prvPrintBufferFirstBankIndex = prv82 + &0D
; prvPrintBufferBankEnd is the high byte of the (exclusive) end address of the
; banks used for the printer buffer. This is &C0 for sideways RAM or &B0 for
; private RAM.
prvPrintBufferBankEnd   = prv82 + &0E
; prvPrintBufferBankList is a 4 byte list of private/sideways RAM banks used by
; the printer buffer. If there are less than 4 banks, the unused entries will be
; &FF. If the buffer is in private RAM, the first entry will be &4X where X is
; the IBOS ROM bank number and the others will be &FF.
prvPrintBufferBankList  = prv83 + &18 ; 4 bytes
prvPrvPrintBufferStart = prv83 + &45 ; working copy of userRegPrvPrintBufferStart

; SFTODO: I believe we do this copy because we want to swizzle it and we mustn't corrupt the user's version, but wait until I've examined more code before writing permanent comment to that effect
prvOswordBlockCopy = prv82 + &20 ; 16 bytes, used for copy of OSWORD &42/&43 parameter block
prvOswordBlockCopySize = 16
; SFTODO: Split prvOswordBlockOrigAddr into two addresses prvOswordX and prvOswordY? Might better reflect how code uses it, not sure yet.
prvOswordBlockOrigAddr = prv82 + &30 ; 2 bytes, used for address of original OSWORD &42/&43 parameter block

prvShx = prv83 + &3D ; &08 on, &FF off SFTODO: Not sure about those on/off values, we test this against 0 in some places - is it &00 on?
prvOsMode = prv83 + &3C ; OSMODE, extracted from relevant bits of userRegOsModeShx SFTODO: WHEN/BY WHAT CODE?
prvTubeReleasePending = prv83 + &42 ; used during OSWORD 42; &FF means we have claimed the tube and need to release it at end of transfer, 0 means we don't
; SFTODO: If private RAM is battery backed, could we just keep OSMODE in
; prvOsMode and not bother with the copy in the low bits of userRegOsModeShx?
; That would save some code.

prvPseudoBankNumbers = prv83 + &08 ; 4 bytes, absolute RAM bank number for the Pseudo RAM banks W, X, Y, Z

prvSFTODOMODE = prv83 + &3F ; SFTODO: this is a screen mode (including a shadow flag in b7), but I'm not sure exactly what screen mode yet - current? *CONFIGUREd? something else?

LDBE6       = &DBE6
LDC16       = &DC16
LF168       = &F168
LF16E       = &F16E

bufNumPrinter = 3 ; OS buffer number for the printer buffer

opcodeCmpAbs = &CD
opcodeLdaAbs = &AD
opcodeStaAbs = &8D

; SFTODO: Define romselCopy = &F4, romsel = &FE30, ramselCopy = &37F, ramsel =
; &FE34 and use those everywhere instead of the raw hex or SHEILA+&xx we have
; now? SFTODO: Or maybe romId instead of romselCopy and ditto for ramselCopy,
; to match the Integra-B documentation, although I find those names a bit less
; intuitive personally.
crtcHorzTotal = SHEILA + &00
crtcHorzDisplayed = SHEILA + &01

romselPrvEn  = &40
romselMemsel = &80
ramselPrvs8  = &10
ramselPrvs1  = &40
ramselShen   = &80
ramselPrvs81 = ramselPrvs8 OR ramselPrvs1

; bits in the 6502 flags registers (as stacked via PHP)
flagC = &01
flagZ = &02
flagV = &40

; Convenience macro to avoid the annoyance of writing this out every time.
MACRO NOT_AND n
             AND #NOT(n) AND &FF
ENDMACRO

; This macro asserts that the given label immediately follows the macro call.
; This makes fall-through more explicit and guards against accidentally breaking
; things when rearranging blocks of code.
MACRO FALLTHROUGH_TO label
          ASSERT P% == label
ENDMACRO

ORG	&8000
GUARD	&C000
.start

;ROM Header Information
.romHeader	JMP language							;00: Language entry point
		JMP service							;03: Service entry point
		EQUB &C2								;06: ROM type - Bits 1, 6 & 7 set - Language & Service
		EQUB copyright MOD &100						;07: Copyright offset pointer
		EQUB &FF								;08: Binary version number
		EQUS "IBOS", 0							;09: Title string
		EQUS "1.20"							;xx: Version string
.copyright	EQUS 0, "(C)"							;xx: Copyright symbol
		EQUS " Computech 1989", 0						;xx: Copyright message

;Store *Command reference table pointer address in X & Y
.CmdRef		LDX #CmdRef MOD &100
		LDY #CmdRef DIV &100
		RTS
		
		EQUS &20								;Number of * commands. Note SRWE & SRWP are not used SFTODO: I'm not sure this is entirely true - the code at searchCmdTbl seems to use the 0 byte at the end of CmdTbl to know when to stop, and if I type "*SRWE" on an emulated IBOS 1.20 machine I get a "Bad id" error, suggesting the command is recognised (if not necessarily useful). It is possible some *other* code does use this, I'm *guessing* the *HELP display code uses this in order to keep SRWE and SRWP "secret" (but I haven't looked yet).
		ASSERT P% = CmdRef + CmdTblOffset
		EQUW CmdTbl							;Start of * command table
		EQUW CmdParTbl							;Start of * command parameter table
		ASSERT P% = CmdRef + CmdTblPtrOffset
		EQUW CmdExTbl							;Start of * command execute address table

;* commands
.CmdTbl		EQUS &06, "ALARM"
		EQUS &09, "CALENDAR"
		EQUS &05, "DATE"
		EQUS &05, "TIME"

		EQUS &0A, "CONFIGURE"
		EQUS &07, "STATUS"
		EQUS &06, "CSAVE"
		EQUS &06, "CLOAD"
		EQUS &05, "BOOT"
		EQUS &07, "BUFFER"
		EQUS &06, "PURGE"
		EQUS &07, "INSERT"
		EQUS &07, "UNPLUG"
		EQUS &05, "ROMS"
		EQUS &07, "OSMODE"
		EQUS &07, "SHADOW"
		EQUS &04, "SHX"
		EQUS &05, "TUBE"
		EQUS &05, "GOIO"
		EQUS &04, "NLE"

		EQUS &07, "APPEND"
		EQUS &07, "CREATE"
		EQUS &06, "PRINT"
		EQUS &08, "SPOOLON"

		EQUS &07, "SRWIPE"
		EQUS &07, "SRDATA"
		EQUS &06, "SRROM"
		EQUS &06, "SRSET"
		EQUS &07, "SRLOAD"
		EQUS &07, "SRSAVE"
		EQUS &07, "SRREAD"
		EQUS &08, "SRWRITE"

		EQUS &05, "SRWE"
		EQUS &05, "SRWP"
		EQUB &00

;Lookup table for recognised * command parameters
.CmdParTbl	EQUS &09, "(", &A6, "(R))/", &A1					;Parameter &80 for *ALARM:		'((=<TIME>(R))/ON/OFF/?)'
		EQUS &04, "(" ,&A7, ")"						;Parameter &81 for *CALENDAR:		'(<DATE>)'
		EQUS &07, "((=)", &A7, ")"						;Parameter &82 for *DATE:		'((=)<DATE>)'
		EQUS &03, &A6, ")"							;Parameter &83 for *TIME:		'(=<TIME>)'
		EQUS &06, &85, "(,", &A8,&AD						;Parameter &84 for *CONFIGURE:	'(<par>)(,<par>)...'
		EQUS &04, "(", &A8, ")"						;Parameter &85 for *STATUS:		'(<par>)'
		EQUS &02, &94							;Parameter &86 for *CSAVE:		'<fsp>'
		EQUS &02, &94							;Parameter &87 for *CLOAD:		'<fsp>'
		EQUS &08, "(<cmd>", &A0						;Parameter &88 for *BOOT:		'(<cmd>/?)'
		EQUS &06, &AF, "/#" , &98, &A0					;Parameter &89 for *BUFFER:		'(<0-4>/#<id>(,<id>).../?)'
		EQUS &03, "(", &A1							;Parameter &8A for *PURGE:		'(ON/OFF/?)'
		EQUS &03, &98,&A2							;Parameter &8B for *INSERT:		'<id>(,<id>)...(I)'
		EQUS &03, &98,&A2							;Parameter &8C for *UNPLUG:		'<id>(,<id>)...(I)'
		EQUS &01								;Parameter &8D for *ROMS:
		EQUS &03, &AF,&A0							;Parameter &8E for *OSMODE:		'(<0-4>/?)'
		EQUS &07, "(", &AE, "1>", &A0, ")"					;Parameter &8F for *SHADOW:		'((<0-1>/?))'
		EQUS &03, "(", &A1							;Parameter &90 for *SHX:		'(ON/OFF/?)'
		EQUS &03, "(", &A1							;Parameter &91 for *TUBE:		'(ON/OFF/?)'
		EQUS &03, "<", &AA							;Parameter &92 for *GOIO:		'<addr>'
		EQUS &01								;Parameter &93 for *NLE:
		EQUS &06, "<fsp>"							;Parameter &94: 			'<fsp>'
		EQUS &04, &94, " ", &AC						;Parameter &95: 			'<fsp> <len>'
		EQUS &02, &94							;Parameter &96:			'<fsp>'
		EQUS &02, &94							;Parameter &97:			'<fsp>'
		EQUS &06, &A5, "(,", &A5, &AD						;Parameter &98:			'<id>(,<id>)...'
		EQUS &02, &98							;Parameter &99:			'<id>(,<id>)...'
		EQUS &02, &98							;Parameter &9A:			'<id>(,<id>)...'
		EQUS &04, "(", &98, &A0						;Parameter &9B:			'(<id>(,<id>).../?)'
		EQUS &05, &94, &AB, &A3, &A2						;Parameter &9C:			'<fsp> <sraddr> (<id>) (Q)(I)'
		EQUS &05, &94, &AB, &A9, &A3						;Parameter &9D:			'<fsp> (<end>/+<len>) (<id>) (Q)'
		EQUS &06, "<", &AA, &A9, &AB, &A4					;Parameter &9E:			'<addr> (<end>/+<len>) <sraddr> (<id>)'
		EQUS &02, &9E							;Parameter &9F:			'<addr> (<end>/+<len>) <sraddr> (<id>)'
		EQUS &04, "/?)"							;Parameter &A0:			'/?)'
		EQUS &08, "ON/OFF", &A0						;Parameter &A1:			'ON/OFF/?)'
		EQUS &04, "(I)"							;Parameter &A2:			'(I)'
		EQUS &06, &A4," (Q)"						;Parameter &A3:			' (<id>) (Q)'
		EQUS &05, " (", &A5, ")"						;Parameter &A4:			' (<id>)'
		EQUS &05, "<id>"							;Parameter &A5:			'<id>'
		EQUS &09, "(=<time>"						;Parameter &A6:			'(=<time>'
		EQUS &07, "<date>"							;Parameter &A7:			'<date>'
		EQUS &06, "<par>"							;Parameter &A8:			'<par>'
		EQUS &0C, " (<end>/+", &AC, ")"					;Parameter &A9:			' (<end>/+<len>)'
		EQUS &06, "addr>"							;Parameter &AA:			'addr>'
		EQUS &06, " <sr", &AA						;Parameter &AB:			' <sraddr>'
		EQUS &06, "<len>"							;Parameter &AC:			'<len>'
		EQUS &05, ")..."							;Parameter &AD:			')...'
		EQUS &05, "(<0-"							;Parameter &AE:			'(<0-'
		EQUS &04, &AE, "4>"							;Parameter &AF:			'(<0-4>'

;lookup table for start address of recognised * commands
.CmdExTbl		EQUW alarm-1							;address of *ALARM command
		EQUW calend-1							;address of *CALENDAR command
		EQUW date-1							;address of *DATE command
		EQUW time-1							;address of *TIME command
		EQUW config-1							;address of *CONFIGURE command
		EQUW status-1							;address of *STATUS command
		EQUW csave-1							;address of *CSAVE command
		EQUW cload-1							;address of *CLOAD command
		EQUW boot-1							;address of *BOOT command
		EQUW buffer-1							;address of *BUFFER command
		EQUW purge-1							;address of *PURGE command
		EQUW insert-1							;address of *INSERT command
		EQUW unplug-1							;address of *UNPLUG command
		EQUW roms-1							;address of *ROMS command
		EQUW osmode-1							;address of *OSMODE command
		EQUW shadow-1							;address of *SHADOW command
		EQUW shx-1							;address of *SHX command
		EQUW tube-1							;address of *TUBE command
		EQUW goio-1							;address of *GOIO command
		EQUW nle-1							;address of *NLE command
		EQUW append-1							;address of *APPEND command
		EQUW create-1							;address of *CREATE command
		EQUW print-1							;address of *PRINT command
		EQUW spool-1							;address of *SPOOLON command
		EQUW srwipe-1							;address of *SRWIPE command
		EQUW srdata-1							;address of *SRDATA command
		EQUW srrom-1							;address of *SRROM command
		EQUW srset-1							;address of *SRSET command
		EQUW srload-1							;address of *SRLOAD command
		EQUW srsave-1							;address of *SRSAVE command
		EQUW srread-1							;address of *SRREAD command
		EQUW srwrite-1							;address of *SRWRITE command
		EQUW srwe-1							;address of *SRWE command
		EQUW srwp-1							;address of *SRWP command
	
;Store *CONFIGURE reference table pointer address in X & Y
.ConfRef	LDX #ConfRef MOD &100
	LDY #ConfRef DIV &100
	RTS

.ConfTbla		EQUB &11								;Number of *CONFIGURE commands
		ASSERT P% = ConfRef + CmdTblOffset ; SFTODO: Or is this not as common-with-CmdRef parsing as I imagine?
		EQUW ConfTbl							;Start of *CONFIGURE commands lookup table
		EQUW ConfParTbl							;Start of *CONFIGURE commands parameter lookup table
	
;*CONFIGURE commands lookup table
.ConfTbl		EQUS &05, "FILE"
		EQUS &05, "LANG"
		EQUS &05, "BAUD"
		EQUS &05, "DATA"
		EQUS &07, "FDRIVE"
		EQUS &08, "PRINTER"
		EQUS &07, "IGNORE"
		EQUS &06, "DELAY"
		EQUS &07, "REPEAT"
		EQUS &05, "CAPS"
		EQUS &03, "TV"
		EQUS &05, "MODE"
		EQUS &05, "TUBE"
		EQUS &05, "BOOT"
		EQUS &04, "SHX"
		EQUS &07, "OSMODE"
		EQUS &06, "ALARM"
		EQUB &00

;*CONFIGURE parameters table
.ConfParTbl	EQUB &07, &81, "(D/N)"						;Parameter &80 for *FILE:		'<0-15>(D/N)'
		EQUB &05, &93, "15>"						;Parameter &81 for *LANG:		'<0-15>'
		EQUB &06, "<1-8>"							;Parameter &82 for *BAUD:		'<1-8>'
		EQUB &04, &93, "7>"							;Parameter &83 for *DATA:		'<0-7>'
		EQUB &02, &83							;Parameter &84 for *FDRIVE:		'<0-7>'
		EQUB &04, &93, "4>"							;Parameter &85 for *PRINTER:		'<0-4>'
		EQUB &06, &93, "255>"						;Parameter &86 for *IGNORE:		'<0-255>'
		EQUB &02, &86							;Parameter &87 for *DELAY:		'<0-255>'
		EQUB &02, &86							;Parameter &88 for *REPEAT:		'<0-255>'
		EQUB &07, &91, &92, "/SH", &92					;Parameter &89 for *CAPS:		'/NOCAPS/SHCAPS'
		EQUB &06, &86, ",", &93, "1>"						;Parameter &8A for *TV:		'<0-255>,<0-1>'
		EQUB &0E, "(", &84, "/<128-135>)"					;Parameter &8B for *MODE:		'(<0-7>/<128-135>)'
		EQUB &06, &91, "TUBE"						;Parameter &8C for *TUBE:		'/NOTUBE'
		EQUB &06, &91, "BOOT"						;Parameter &8D for *BOOT:		'/NOBOOT'
		EQUB &05, &91, "SHX"						;Parameter &8E for *SHX:		'/NOSHX'
		EQUB &02, &85							;Parameter &8F:			'<0-4>'
		EQUB &05, &93, "63>"						;Parameter &90:			'<0-63>'
		EQUB &04, "/NO"							;Parameter &91:			'/NO'
		EQUB &05, "CAPS"							;Parameter &92:			'CAPS'
		EQUB &04, "<0-"							;Parameter &93:			'<0-'
		EQUB &00

;Store IBOS Options reference table pointer address in X & Y
.ibosRef	  LDX #ibosRef MOD &100
            LDY #ibosRef DIV &100
            RTS

		EQUB &04								;Number of IBOS options
		EQUW ibosTbl							;Start of IBOS options lookup table
		EQUW ibosParTbl							;Start of IBOS options parameters lookup table (there are no parameters!)
		EQUW ibosSubTbl							;Start of IBOS sub option reference lookup table

.ibosTbl		EQUS &04, "RTC"
		EQUS &04, "SYS"
		EQUS &04, "FSX"
		EQUS &05, "SRAM"
		EQUB &00

.ibosParTbl	EQUB &01,&01,&01,&01
		EQUB &00

.ibosSubTbl	EQUW CmdRef
		EQUB &00,&03							;&04 x IBOS/RTC Sub options - from offset &00
		EQUW CmdRef
		EQUB &04,&13							;&10 x IBOS/SYS Sub options - from offset &04
		EQUW CmdRef
		EQUB &14,&17							;&04 x IBOS/FSX Sub options - from offset &14
		EQUW CmdRef
		EQUB &18,&1F							;&08 x IBOS/SRAM Sub options - from offset &18
		EQUW ibosRef
		EQUB &00,&03							;&04 x IBOS Options - from offset &00
		EQUW ConfRef
		EQUB &00,&10							;&11 x CONFIGURE Parameters - from offset &00
	
;Test for valid command
;On entry, X & Y contain lookup table address. A=0 SFTODO: I don't think A is always 0 on entry, e.g. see code just above notNoSh (and if A was always 0 on entry, it would be redundant to add it to transientCmdPtr) - SFTODO: I think A is the offset from transientCmdPtr, ie the value we would normally have in Y - sometimes we presumably know Y is 0 (thanks to the normalising done in setTransientCmdPtr) and it's just more convenient to call with A=0
;&A8 / &A9 contain end of command parameter address in buffer
; SFTODO: Among other things, returns with carry clear and X containing index if we found a match, otherwise with carry set
.searchCmdTbl
{
transientTblCmdLength = L00AC
.L833C	  PHA									;save A
            CLC
	  ADC transientCmdPtr
	  STA transientCmdPtr	
	  BCC L8346
            INC transientCmdPtr + 1
.L8346      STX transientTblPtr							;look up table address at &AA / &AB
            STY transientTblPtr + 1
            LDY #CmdTblOffset								;lookup table initial offset to get first address 
            LDA (transientTblPtr),Y
            TAX
            INY									;Y=&07
            LDA (transientTblPtr),Y
            STX transientTblPtr
            STA transientTblPtr + 1							;store first address from lookup table in &AA / &AB
	  ; SFTODO: Can we shorten the following decrement-by-one using http://www.obelisk.me.uk/6502/algorithms.html technique?
            SEC
            LDA transientCmdPtr
            SBC #&01
            STA transientCmdPtr
            BCS L8361
            DEC transientCmdPtr + 1							;and reduce end of command parameter address by 1
.L8361      LDX #&00								;set pointer to first command
            LDY #&00								;set pointer to first byte of command
            LDA (transientTblPtr),Y							;get first byte from lookup table address. This is the length of the command string
.L8367      STA transientTblCmdLength							;and save at &AC
            INY
.L836A      LDA (transientCmdPtr),Y							;get character from input buffer
	  ; SFTODO: Any chance of simultaneously optimising-and-improving by having a subroutine to convert A to upper case and JSRing to it everywhere we want to do that?
            CMP #&60								;'£'
            BCC L8372
            AND #&DF								;capitalise
.L8372      CMP (transientTblPtr),Y							;compare with character from lookup table
            BNE L837E								;if not equal do further checks (check for short command '.') 
            INY									;next character
            CPY transientTblCmdLength								;until end of command string
            BEQ cmdMatchesTbl								;reached the end of the check. All good, so process.
            JMP L836A								;loop
			
.L837E      CMP #'.'
            BNE L838D								;command not matched. Check next command.
            CPY #&03								;check length of command.
            BCC L838D								;If less than 3, then too short, even if initial characters match, so check next command
            INY									;next character
.cmdMatchesTbl
	  ; SFTODO: Note that we don't check for a space or CR following the command, so IBOS will (arguably incorrectly) recognise things like "*STATUSFILE" as "*STATUS FILE" instead of not claiming them and allowing lower priority ROMs to match against them. To be fair this is probably OK, it looks like a Master 128 does the same at least with *SRLOAD, and I think "*SHADOW1" is relatively conventional.
	  ; SFTODO: Possibly related and possibly not - doing "*CREATEME" on (emulated) IBOS 1.20 seems to sometimes do nothing and sometimes generate a pseudo-error, as if the parsing is going wrong. Changing "ME" for other strings can make a difference.
	  JSR findNextCharAfterSpace							;Command recognised. find first command parameter after ' '. offset stored in Y.
            CLC									;clear carry - ??? ; SFTODO: SUCCEEDED IN MATCHING?
            BCC foundCmd								;and jump
.L838D      INX									;next command
            CLC
            LDA transientTblPtr
            ADC transientTblCmdLength							;get length of command string for previous command
            STA transientTblPtr								
            BCC L8399
            INC transientTblPtr + 1							;and update lookup table address to point at start of next command
.L8399      LDY #&00								;set pointer to first byte of command
            LDA (transientTblPtr),Y							;check for end of table
            BNE L8367								;if not end of table, then loop
            SEC									;set carry - ??? SFTODO: FAILED TO MATCH?

			
.foundCmd   DEY									;get back to last character
            INC transientCmdPtr							;
            BNE L83A7
            INC transientCmdPtr + 1							;and increment lookup table address instead SFTODO: why do we bother doing this though?
.L83A7      PLA									;restore A
            RTS									;and finish
;End of test for valid commands
}
			
			
.L83A9      PHA
            JSR ibosRef
            STX L00AA
            STY L00AB
            LDY #&0A
            LDA (L00AA),Y
            TAX
            INY
            LDA (L00AA),Y
            STA L00AB
            STX L00AA
            PLA
            PHA
            ASL A
            ASL A
            TAY
            LDA (L00AA),Y
            PHA
            INY
            LDA (L00AA),Y
            PHA
            INY
            LDA (L00AA),Y
            STA L00A8
            INY
            LDA (L00AA),Y
            STA L00A9
            PLA
            STA L00AB
            PLA
            STA L00AA
.L83D9      LDX L00AA
            LDY L00AB
            LDA L00A8
            CLC
            CLV
            JSR L83FB
            INC L00A8
            CMP L00A9
            BCC L83D9
            PLA
            RTS
			
.L83EC      JSR CmdRef								;get start of *command pointer look up table address X=&26, Y=&80
            JMP L83F5
			
{
; SFTODO: Use a different local label instead of transientTblPtr in here? I am not sure what would be clearest as still working through code...
.^L83F2     JSR ConfRef
.^L83F5     CLC
            BIT rts									;set V
            LDA L00AA
.^L83FB     PHA									;save current contents of &AA
            LDA L00AB
            PHA									;save current contents of &AB
            LDA L00AA
            PHA									;save current contents of &AA again
            STX transientTblPtr
            STY transientTblPtr + 1								;save start of *command pointer lookup table address to &AA / &AB
            JSR startDynamicSyntaxGeneration

            TSX									;get stack pointer
            LDA L0103,X								;get A saved at L83FB from stack
            PHA									;and save
            LDY #CmdTblOffset								;offset for address *command lookup table
            LDA (transientTblPtr),Y
            TAX
            INY
            LDA (transientTblPtr),Y
            TAY									;save start of *command lookup table address to X & Y
            PLA									;recover stack value
            JSR L8461PreservingAAAB								;write *command to screen???
            LDA #&09
            JSR emitDynamicSyntaxCharacter

            BIT transientDynamicSyntaxState						
            BVS dontSFTODO

            TSX									;get stack pointer
            LDA L0103,X								;read value from stack
            PHA									;and save
            LDY #&08								;offset for address *command parameters lookup table
            LDA (transientTblPtr),Y
            TAX
            INY
            LDA (transientTblPtr),Y
            TAY									;save start of *command parameters lookup table to X & Y
            PLA									;recover stack value
            JSR L8461PreservingAAAB								;write *command parameters to screen???
            LDA #&0D
            JSR emitDynamicSyntaxCharacter

.dontSFTODO
            PLA
            STA L00AA
            PLA
            STA L00AB
            PLA
.rts        RTS
}

;move the correct reference address into &AA / &AB
;on entry X & Y contain address of either *command or *command parameter lookup table
; SFTODO: An example of something YX might point to is ConfTbl
.L8461PreservingAAAB ; SFTODO: rename - it's *is* preserving them, but it's also calling L8461 with those set up with our YX, so maybe L8461UsingYX would be a better name
{
.L8443      PHA									;save stack value
            TXA									;get start of *command or *command parameters lookup table low address
            PHA									;and save
            LDA L00AA								;get *command pointer look up table low address
            PHA									;and save
            LDA L00AB								;get *command pointer look up table high address
            PHA									;and save
            STX L00AA
            STY L00AB								;save start of *command or *command parameter look up table address to &AA / &AB
            TSX									;get stack pointer
            LDA L0104,X								;get A on entry from stack
            JSR L8461								;write parameters to screen?
            PLA										
            STA L00AB
            PLA
            STA L00AA								;start of *command or *command parameter look up table address restored to &AA / &AB
            PLA
            TAX									;restore X register
            PLA									;restore A register
            RTS									;and return
}
			
;write *command or *command parameters to screen
{
; SFTODO: Instead of preserving A8/A9 and copying AA/AB onto them, could this just work directly with AA/AB? I think the main reason it couldn't is if our caller assumes they are preserved, I don't know if that is true yet.
ptr = &A8
tmp = &AC
.^L8461     PHA									;save stack value
            TXA
            PHA									;save contents of X
            TYA
            PHA									;save contents of Y
            LDA ptr + 1
            PHA									;save contents of &A9
            LDA ptr
            PHA									;save contents of &A8
            LDA tmp
            PHA									;save contents of &AC
            TSX									;get stack pointer
            LDA L0106,X								;get A on entry from stack
            AND #&7F								;mask out bit 7
            STA tmp									;and store at &AC
            LDA L00AA
            STA ptr									;copy &AA to &A8
            LDA L00AB
            STA ptr + 1								;copy &AB to &A9

	  ; Advance ptr so it points to the (A on entry with bit 7 masked off)th entry in the table.
            LDX #&00
            LDY #&00								;y is fixed at &00
.advanceLoop
	  CPX tmp									;A on entry with bit 7 masked off
            BEQ advanceLoopDone
            CLC
	  LDA (ptr),Y
            ADC ptr
            STA ptr
	  ; SFTODO: We could use the BCC label:INC:.label trick here to shorten this
            LDA ptr + 1
            ADC #&00
            STA ptr + 1
            INX
            BNE advanceLoop
.advanceLoopDone
			
            LDA (ptr),Y								;get length of string plus 1
            STA tmp
            CMP #&01
            BEQ charLoopDone ; SFTODO: can this happen? do we have "zero length strings"?
            INY
.charLoop   LDA (ptr),Y
            BPL L84AA ; SFTODO: b7 of table entries must mean something - we do L8461 or emitDynamicSyntaxCharacter according to it
            JSR L8461
            JMP L84AD
.L84AA      JSR emitDynamicSyntaxCharacter
.L84AD      INY
            CPY tmp
            BNE charLoop
.charLoopDone
	  PLA
            STA tmp
            PLA
            STA ptr
            PLA
            STA ptr + 1
            PLA
            TAY
            PLA
            TAX
            PLA
            RTS
}
			
; If entered with C set this starts to dynamically construct a "Syntax: ..." error on the stack
; If entered with C clear this outputs a "  " prefix iff V is clear on entry and otherwise (SFTODO:being deliberately vague) prepares for generating the syntax message
; SFTODO: This has only one caller
.startDynamicSyntaxGeneration ; SFTODO: rename?
{
.L84C1      LDA #&00
            ROR A ; move C on entry into b7 of A
            BVC L84C8
            ORA #&40
.L84C8      STA transientDynamicSyntaxState ; stash original V (&40, b6) and C (&80, b7) in transientDynamicSyntaxState
            BPL L84DD ; don't generate an error if C is clear
            LDY #&00
.L84CE      LDA L84EE,Y
            STA L0100,Y
            INY
            CMP #' '
            BNE L84CE
            TYA
            JMP L84E9
			
.L84DD      BIT transientDynamicSyntaxState
            BVS L84E7
            JSR printSpace								;write ' ' to screen
            JSR printSpace								;write ' ' to screen
.L84E7      LDA #&02
.L84E9      ORA transientDynamicSyntaxState
            STA transientDynamicSyntaxState
            RTS

.L84EE  	  EQUB &00,&DC
	  EQUS "Syntax: "
}

; SFTODO: I haven't got this completely worked out, but roughly speaking it "emits" A into the current dynamic syntax message depending on the flags, allowing TAB characters to be expanded where appropriate so things line up nicely on screen
.emitDynamicSyntaxCharacter
{
.L84F8      BIT transientDynamicSyntaxState
            BPL SFTODOCASEB
            PHA
            TXA
            PHA
            TSX
            LDA L0102,X								;get A on entry
            PHA
            LDA transientDynamicSyntaxState
            AND #transientDynamicSyntaxStateCountMask
            TAX
            PLA
            STA L0100,X
            CMP #&0D ; SFTODO: vduCr?
            BNE L8519
            LDA #&00
            STA L0100,X
            JMP L0100
			
.L8519      INC transientDynamicSyntaxState
            PLA
            TAX
            PLA
            RTS
			
.L851F      INC transientDynamicSyntaxState
            JMP OSASCI
			
.SFTODOCASEB
            CMP #&09
            BNE L851F
            TXA
            PHA
            LDA transientDynamicSyntaxState
            AND #transientDynamicSyntaxStateCountMask
            TAX
            LDA #' '
.L8531      CPX #&0C
            BCS L853B
            JSR OSWRCH
            INX
            BNE L8531
.L853B      PLA
            TAX
            RTS
}
			
;Find next character after space.
;On exit A=character Y=offset for character. Carry set if end of line
;X is preserved.
{
.L853E      INY
.^findNextCharAfterSpace
.L853F      LDA (transientCmdPtr),Y
            CMP #' '
            BEQ L853E
            CMP #vduCr
            BEQ L854B
            CLC
            RTS

; SFTODO: Many copies of these two instructions, can we share?
.L854B      SEC
            RTS

.^L854D      JSR findNextCharAfterSpace								;find next character. offset stored in Y
            BCS L854B
            LDA (transientCmdPtr),Y
            CMP #&2C								;','
            BNE L8559
            INY
.L8559      CLC
            RTS
}

;Unrecognised Star command
.service04
{
	  JSR setTransientCmdPtr
            JSR CmdRef								;get start of * command look up table address X=&26, Y=&80
            JSR searchCmdTbl								;test for valid * command
            BCC runCmd								;branch if found a valid * command
            TAY
            LDA (transientCmdPtr),Y
            AND #&DF								;capitalise
            CMP #'I'								;'I' - All Integra-B commands can be prefixed with 'I' to distinguish from other commands
            BNE L857E								; if not 'I', then test for '*X*' or '*S*' commands
            INY										
            TYA									;so try again, with A=1 and Y=1
            JSR CmdRef								;get start of * command look up table address X=&26, Y=&80
            JSR searchCmdTbl								;test for valid * command
            BCC runCmd								;branch if found a valid * command

.L8579      LDA #&04 ; SFTODO: redundant? exitSCa immediately does PLA
            JMP exitSCa								;restore service call parameters and exit
			
.L857E      INY									;
            LDA (transientCmdPtr),Y							;read second character
            CMP #'*'
            BNE L8579								;if not, then restore and exit
            DEY
            LDA (transientCmdPtr),Y
            AND #&DF								;capitalise
            CMP #'X'								;'X' - '*X*' command
            BNE L8591								;if not, then check for '*S*'
            JMP commandX								;execute '*X*' command
			
.L8591      CMP #'S'								;'S' - Undocumented '*S*' command
            BNE L8579								;if not, then restore and exit
            JMP commandS								;execute '*S*' command
			
.runCmd
	  ; Transfer control to CmdRef[CmdTblPtrOffset][X], preserving Y (the index into the next byte of the command tail after the * command).
	  STY L00AD
            STX L00AC
            JSR CmdRef								;get start of * command look up table address X=&26, Y=&80
            STX transientTblPtr
            STY transientTblPtr + 1
            LDY #CmdTblPtrOffset
            LDA (transientTblPtr),Y
            TAX
            INY
            LDA (transientTblPtr),Y
            STA transientTblPtr + 1
            STX transientTblPtr
            LDA L00AC								;get matching command index
            ASL A									;double it as we have 16-bit entries at CmdTblPtrOffset
            TAY
            INY
            LDA (transientTblPtr),Y
            PHA
            DEY
            LDA (transientTblPtr),Y
            PHA
            LDX L00AC
            STX L00AA ; SFTODO: why do we bother? does any command use this? (I think X=index of the command in the table)
            LDY L00AD
            RTS
}

;*HELP Service Call
.service09
            JSR setTransientCmdPtr
            LDA (L00A8),Y
            CMP #&0D
            BNE L85F1
            LDX #&04
.L85CD      TXA
            PHA
            JSR OSNEWL
            LDX #&09								;Print Title String
.L85D4      LDA romHeader,X
            BNE L85DB
            LDA #&20
.L85DB      JSR OSWRCH
            INX
            CPX romHeader+7
            BNE L85D4
            JSR OSNEWL
            PLA
            JSR ibosRef
            JSR L83A9
            JMP L85FB
			
.L85F1      JSR ibosRef
            LDA #&00
            JSR searchCmdTbl
            BCC L85CD
.L85FB      JMP exitSCa								;restore service call parameters and exit

; Return with A=Y=0 and (transientCmdPtr),Y accessing the same byte as (osCmdPtr),Y on entry.
.setTransientCmdPtr
{
.L85FE      CLC
            TYA									;offset used with osCmdPtr to access next character SFTODO: earlier comment called this "length", I don't think that's right (at least in case of service call 4) but it may be this does act as a kind of length in some other context, so keeping this note around until I've been through all the callers
            ADC osCmdPtr			
            STA transientCmdPtr							;end of command parameter lo byte
            LDA osCmdPtr + 1
            ADC #&00
            STA transientCmdPtr + 1							;end of command parameter hi byte
            LDA #&00								;A=0
            TAY									;Y=0
            RTS
}
			
; SFTODO: I haven't traced through this code yet, but I infer that it's reponsible for printing "Syntax: " followed by the *HELP definition of the command.
.syntaxError
{
.L860E      JSR PrvDis								;switch out private RAM
            LDA L00AA
            JSR CmdRef								;get start of * command look up table address X=&26, Y=&80
            SEC
            JMP L83FB
}

;service entry point
.service
{
            PHA										;save service type
            TXA
            PHA										;save ROM number
            TYA
            PHA										;save ROM parameter
            TSX
            LDA L0103,X								;get original A we stacked just above
            BEQ exitSCa								;restore service call parameters and exit
            CMP #&05
            BNE L8635								;Process lookup table if not equal to &05
            ; We're handling service call 5 - unrecognised interrupt.
            ; SFTODO: I'm guessing this is something to do with the RTC generating an interrupt when alarm time occurs.
            LDX #&0C								;Select 'Register C' register on RTC: Register &0C
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            CMP #&80								;Interrupt Request Flag
            BCC exitSCa								;restore service call parameters and exit
            JMP LB46E								;

.L8635      LDX #&0B
.L8637      CMP srvCallLU,X
            BEQ L864E
            DEX
            BPL L8637

;restore service call parameters and exit
.^exitSCa   PLA										;restore ROM parameter
            TAY
            PLA										;restore ROM number
            TAX
            PLA										;restore service type
            RTS

.^exitSC    TSX
            LDA #&00
            STA L0103,X
            JMP exitSCa								;restore service call parameters and exit

.L864E      TXA
            ASL A
            TAX
            LDA srvAddrLU+1,X
            PHA
            LDA srvAddrLU,X
            PHA
            RTS

;Service call lookup table
.srvCallLU	EQUB &09								;*HELP instruction expansion
		EQUB serviceConfigure						;*CONFIGURE command
		EQUB serviceStatus							;*STATUS command
		EQUB &04								;Unrecognised Star command
		EQUB &FF								;Tube system initialisation
		EQUB &10								;SPOOL/EXEC file closure warning
		EQUB &03								;Autoboot
		EQUB &01								;Absolute workspace claim
		EQUB &0F								;Vectors claimed - Service call &0F
		EQUB &06								;Break - Service call &06
		EQUB &08								;Unrecognised OSWORD call
		EQUB &07								;Unrecognised OSBYTE call

;Service call execute address lookup table
.srvAddrLU	EQUW service09-1							;Address for *HELP
		EQUW service28-1							;Address for *CONFIGURE command
		EQUW service29-1							;Address for *STATUS command
		EQUW service04-1							;Address for Unrecognised Star command
		EQUW serviceFF-1							;Address for Tube system initialisation
		EQUW service10-1							;Address for SPOOL/EXEC file closure warning
		EQUW service03-1							;Address for Autoboot
		EQUW service01-1							;Address for Absolute workspace claim
		EQUW service0F-1							;Address for Vectors claimed
		EQUW service06-1							;Address for Break
		EQUW service08-1							;Address for unrecognised OSWORD call
		EQUW service07-1							;Address for unrecognised OSBYTE call
}

; Generate an error using the error number and error string immediately following the "JSR raiseError" call.
.raiseError
{
.L867E      JSR PrvDis								;switch out private RAM
            PLA
            STA L00FD
            PLA
            STA L00FE
            LDY #&01
.L8689      LDA (L00FD),Y
            STA L0100,Y								;relocate error text
            BEQ L8693
            INY
            BNE L8689
.L8693      STA L0100								;forced BRK
            JMP L0100
}
			
			
.L8699      JSR findNextCharAfterSpace								;find next character. offset stored in Y
            LDA (L00A8),Y
            AND #&DF
            CMP #&4F
            BNE L86C4
            INY
            LDA (L00A8),Y
            AND #&DF
            CMP #&4E
            BNE L86B2
            INY
            LDA #&FF
            CLC
            RTS
			
.L86B2      CMP #&46
            BNE L86C4
            INY
            LDA (L00A8),Y
            AND #&DF
            CMP #&46
            BNE L86C0
            INY
.L86C0      LDA #&00
            CLC
            RTS
			
.L86C4      LDA #&7F
            SEC
            RTS

.L86C8      PHA
            LDA #'O'
            JSR OSWRCH
            PLA
            BEQ L86D6					;'OFF' if 0, otherwise 'ON'
            LDA #'N'
            JMP OSWRCH					;write 'ON' to screen
			
.L86D6      LDA #'F'
            JSR OSWRCH
            JMP OSWRCH					;write 'OFF' to screen
			
;Convert binary number in A to numeric characters and write characters to screen
;C set on entry means left pad to three characters with spaces, clear means no padding.
;A is preserved
.printADecimal
{
pad = &B0 ; character output in place of leading zeros
padFlag = &B1 ; b7 clear iff "0" should be converted into "pad" 

.L86DE      PHA
            LDA #&00
            STA padFlag
            BCS noPadding ; we use NUL for padding, which has the same effect
            LDA #' '
.noPadding  STA pad
            PLA
            PHA

            LDX #0 ; SFTODO: change to LDX #&FF and get rid of DEX/INX stuff?
            SEC
.hundredsLoop
            SBC #100
            INX
            BCS hundredsLoop
            ADC #100
            JSR printDigit

            LDX #0 ; SFTODO: change to LDX #&FF and get rid of DEX/INX stuff?
            SEC
.tensLoop
            SBC #10
            INX
            BCS tensLoop
            ADC #10
            JSR printDigit

            TAX
            INX ; SFTODO: optimisable?
            DEC padFlag
            JSR printDigit
            PLA
            RTS
			
.printDigit
            PHA
            DEX ; SFTODO: optimisable?
            LDA pad
            CPX #&00 ; SFTODO: Could get rid of this if LDA moved before DEX
            BNE notZero
            BIT padFlag
            BPL printPad
.notZero    DEC padFlag
            TXA
            ORA #'0'								;Convert binary number to ASCII number
.printPad   JSR OSWRCH								;Write number to screen
            PLA
            RTS
}
			
.convertIntegerDefaultHex
{
.L8724      LDA #16
            JMP convertIntegerDefaultBaseA
}

; Convert an number expressed in ASCII at (transientCmdPtr),Y into a 32-bit
; integer. It may be prefixed with '-' for negative, '&' indicates hex, '%'
; indicates binary and '+' indicates decimal.
;
; SFTODO: The next two lines seem wrong - we return with C *clear* if and only if a number has been parsed successfully, otherwise we return with C set - in this case I think V is clear if there is nothing to parse, or set if there is something but we can't parse it - not 100% sure about this, and need to check code again.
; Returns with V clear if there is no number to parse; C is not altered.
; Otherwise C is set if and only if a number is parsed successfully.
; If we parse successfully, the integer is at &B0 (SFTODO: do we use this?
; probably) and the low byte is in A.
; If we fail to parse successfully, we beep and return with A=0.
; SFTODO: I guess it's an IBOS thing, but that beep seems a bit odd - I think
; this is used for commands implemented on B+/Master like SRLOAD and I don't
; think their SRLOAD will ever beep.
; SFTODO: Use of &Bx zp here seems iffy, this is filing system workspace. Did we
; save it somewhere first? Even so, seems less than ideal - what if an interrupt
; occurs?
; SFTODO: Any chance of shrinking this code using loops to work on the 4-byte values?
{
result = &B0 ; 4 bytes
base = &B8
negateFlag = &B9
originalCmdPtrY = &BA
firstDigitCmdPtrY = &BB

; SFTODO: Could we share this fragment?
.clvRts
.L8729      CLV
            RTS

.^convertIntegerDefaultDecimal
.L872B      LDA #10
.^convertIntegerDefaultBaseA
.L872D      STA base
            JSR findNextCharAfterSpace							;find next character. offset stored in Y
            BCS clvRts                                                                              ;return with V set if it's a carriage return
            STY originalCmdPtrY
            STY firstDigitCmdPtrY
            LDA #&00
            STA result
            STA result + 1
            STA result + 2
            STA result + 3
            STA negateFlag
            LDA (transientCmdPtr),Y
            CMP #'-'
            BNE L8753
            LDA #&FF
            STA negateFlag
.L874E      LDA #10
            JMP L8766
			
.L8753      CMP #'+'
            BEQ L874E
            CMP #'&'
            BNE L8760
            LDA #&10
            JMP L8766
			
.L8760      CMP #'%'
            BNE L87B9
            LDA #2
.L8766      STA base
            INY
            STY firstDigitCmdPtrY
            JMP L87B9
			
.L876E      TAX
            LDA result
            STA L00B4
            STX result
            LDX #&00
            LDA result + 1
            STA L00B5
            STX result + 1
            LDA result + 2
            STA L00B6
            STX result + 2
            LDA result + 3
            STA L00B7
            STX result + 3
            LDA base
            LDX #&08
.L878D      LSR A
            BCC L87AD
            PHA
            CLC
            LDA result
            ADC L00B4
            STA result
            LDA result + 1
            ADC L00B5
            STA result + 1
            LDA result + 2
            ADC L00B6
            STA result + 2
            LDA result + 3
            ADC L00B7
            STA result + 3
            PLA
            BVS L8806
.L87AD      ASL L00B4
            ROL L00B5
            ROL L00B6
            ROL L00B7
            DEX
            BNE L878D
            INY
.L87B9      LDA (transientCmdPtr),Y
            CMP #'Z'+1
            BCC L87C1
            AND #&DF                                                                                ;convert to upper case
.L87C1      SEC
            SBC #'0'
            CMP #10
            BCC L87CE
            SBC #('A' - 10) - '0'
            CMP #10
            BCC L87D2
.L87CE      CMP base
            BCC L876E
.L87D2      BIT negateFlag
            BPL L87EF
            SEC
            LDA #&00
            SBC result
            STA result
            LDA #&00
            SBC result + 1
            STA result + 1
            LDA #&00
            SBC result + 2
            STA result + 2
            LDA #&00
            SBC result + 3
            STA result + 3
.L87EF      CPY firstDigitCmdPtrY
            BEQ L87F8
            CLC
            CLV
            LDA result
            RTS
			
.L87F8      LDA #vduBell
            JSR OSWRCH								;Generate VDU 7 beep
            LDA #&00
            LDY originalCmdPtrY
            SEC
            BIT rts									;set V
.rts        RTS

.L8806      JMP badParameter
}

.errorNotFound
{
.L8809      JSR raiseError								;Goto error handling, where calling address is pulled from stack

		EQUB &D6
		EQUS "Not found", &00
}

{
;Condition then read from Private RAM &83xx (Addr = X, Data = A)
.L8817      JSR setXMsb								;Set msb of Addr (Addr = Addr OR &80)
            JSR readPrivateRam8300X								;read data from Private RAM &83xx (Addr = X, Data = A)
            JMP L8826								;Clear msb of Addr (Addr = Addr & &7F)
			
;Condition then write to Private RAM &83xx (Addr = X, Data = A)
.L8820      JSR setXMsb								;Set msb of Addr (Addr = Addr OR &80)
            JSR writePrivateRam8300X								;write data to Private RAM &83xx (Addr = X, Data = A)

;Clear msb of Addr (Addr = Addr & &7F)			
.L8826      PHA
            TXA
            AND #&7F
            TAX
            PLA
            RTS		

;Set msb of Addr (Addr = Addr OR &80)
.setXMsb
.L882D      PHA
            TXA
            ORA #&80
            TAX
            PLA
            RTS

; Read/write A from/to user register X. X is preserved on exit.
; For X<=&31, the user register is held in RTC register X+&0E.
; For &32<=X<=&7F, the user register is held in private RAM at &8380+X.
; For X>=&80, these subroutines do nothing.
; SFTODO: Does the code rely on that behaviour for X>=&80?
; SFTODO: These two routines start off very similar, can we share code?
; SFTODO: A fair amount of the code/complexity here is preserving X. Do callers
; need this/could they be easily changed not to need it? If we don't have to
; worry about being re-entrant, is there a byte of main RAM we could use to stash
; X in on entry.

.^readUserReg
	  CPX #&80
            BCS rts  								;Invalid if Address >=&80
            CPX #&32
            BCS L8817								;Read from Private RAM if Address >&32 and <&80
            PHA
            CLC
            TXA
            ADC #rtcUserBase								;Increment address by &0E bytes. First &0E bytes are for the RTC data
            TAX
            PLA
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            JMP L885B

.^writeUserReg
	  CPX #&80
            BCS rts  								;Invalid if Address >=&80
            CPX #&32
            BCS L8820								;Write to Private RAM if Address >&32 and <&80
            PHA
            CLC
            TXA
            ADC #rtcUserBase								;Increment address by &0E bytes. First &0E bytes are for the RTC data
            TAX
            PLA
            JSR wrRTCRAM								;Write data from A to RTC memory location X
			
.L885B      PHA
            TXA
            SEC
            SBC #rtcUserBase								;Restore address by reducing address by &0E bytes. First &0E bytes are for the RTC data
            TAX
            PLA
            CLC
.rts
.L8863      RTS
}

;write data to Private RAM &83xx (Addr = X, Data = A)
.writePrivateRam8300X
{
.L8864      PHP
            SEI
            JSR switchInPrivateRAM
            STA prv83,X								;write data to Private RAM (Addr = X, Data = A)
            PHA
            JMP switchOutPrivateRAM
}

;read data from Private RAM &83xx (Addr = X, Data = A)
.readPrivateRam8300X
{
.L8870      PHP
            SEI
            JSR switchInPrivateRAM
            LDA prv83,X								;read data from Private RAM (Addr = X, Data = A)
            PHA
            ; SFTODO: We could move switchOutPrivateRAM just after this code and
            ; fall through to it, saving three bytes.
            JMP switchOutPrivateRAM
}

;Switch in Private RAM
.switchInPrivateRAM
{
.L887C      PHA
            LDA ramselCopy
            AND #&80
            ORA #&40
            STA ramsel							;retain value of ramselCopy so it can be restored after read / write operation complete
            LDA romselCopy
            ORA #&40
            STA romsel							;retain value of &F4 so it can be restored after read / write operation complete
            PLA
            RTS
}

;Switch out Private RAM
.switchOutPrivateRAM
{
.L8890      LDA romselCopy
            STA romsel							;restore using value retained in &F4
            LDA ramselCopy
            STA ramsel							;restore using value retained in ramselCopy
            PLA
            PLP
            PHA
            PLA
            RTS
}

.stackTransientCmdSpace
{
.L88A0      LDX #&07
.L88A2      LDA L00A8,X								;Copy 8 values from &AF-&A8 to the stack
            PHA
            DEX
            BPL L88A2
            PHA										;Create space on the stack
            PHA										;for a return address.
            TSX
            LDA L010B,X								;Copy the original return address
            STA L0101,X								;into the space just created.
            LDA L010C,X
            STA L0102,X
            RTS										;Return to the caller.
}

; SFTODO: This currently only has one caller and could be inlined.
.unstackTransientCmdSpace
{
.L88B8      TSX
            LDA L0101,X
            STA L010B,X
            LDA L0102,X
            STA L010C,X
            PLA
            PLA
            LDX #&00
.L88C9      PLA
            STA L00A8,X
            INX
            CPX #&08
            BCC L88C9
            RTS
}
						
;Unconfirmed language entry point
.language   CMP #&01								;Check if valid language entry
            BEQ L88E2								;Jump to confirmed language entry
            RTS										;Not a valid language entry

			
;Set BRK Vector
.L88D7      LDA #L8969 MOD &100			
            STA BRKVL
            LDA #L8969 DIV &100
            STA BRKVH
            RTS

			
;Confirmed language entry point
.L88E2      CLI							
            CLD
            LDX #&FF
            TXS
            JSR L88D7								;Set BRK Vector to &8969
            LDA lastBreakType								;Read current language ROM number
            BNE L88F2
            JMP L898E
			
.L88F2      LDA #&7A
            JSR OSBYTE								;Perform key scan
            CPX #&47								;Is the @ key being pressed?
            BEQ L88FE
            JMP L898E
			
.L88FE      LDA #&C8								;Start of RESET routine
            LDX #&02					
            LDY #&00
            JSR OSBYTE								;Memory cleared on next reset
            LDX #&00								;Write 'System Reset' text to screen
.L8909      LDA L894F,X
            BEQ L8914
            JSR OSASCI
            INX
            BNE L8909
.L8914      LDA #&7A
            JSR OSBYTE								;Perform key scan
            CPX #&47								;Is the @ key being pressed?
            BEQ L8914								;Repeat until no longer being pressed
            LDA #&15
            LDX #&00
            JSR OSBYTE								;Flush keyboard buffer
            CLI
            JSR OSRDCH								;Read keyboard
            PHA
            LDA #&7E
            JSR OSBYTE								;Was ESC pressed?
            PLA
            AND #&DF								;Capitalise
            CMP #&59								;Was Y pressed?
            BNE L8943								;No? Clear screen, then NLE
            LDX #&03
.L8937      LDA L894B,X								;Yes? Write 'Yes' to screen
            JSR OSWRCH
            DEX
            BPL L8937								;Loop
            JMP L89C2								;Initiate Full Reset
			
.L8943      LDA #&0C
            JSR OSWRCH								;Clear Screen
            JMP nle									;Enter NLE

.L894B      EQUS &0D, "seY"
.L894F      EQUS "System Reset", &0D, &0D, "Go (Y/N) ? ", &00

;BRK vector entry point
.L8969	  LDX #&FF								;Break Vector routine
	  TXS
            CLI
            CLD
            LDA #&DA
            LDX #&00
            LDY #&00
            JSR OSBYTE
            LDA #&7E
            JSR OSBYTE
            JSR OSNEWL
            LDY #&01
.L8981      LDA (L00FD),Y
            BEQ L898B
            JSR OSWRCH
            INY
            BNE L8981
.L898B      JSR OSNEWL
.L898E      JSR L89A3
            JSR L89A8
            LDX #&00
            LDY #&07
            JSR OSCLI
            JMP L898E
			
.L899E
;OSWORD A=&0, Read line from input - Parameter block
; SFTODO: Use of L0700 in next line is potentially iffy, but I suspect this is used only when we're in NLE when IBOS *is* current language, so that would be fine
		EQUW L0700							;buffer address
		EQUB &FF								;maximum line length
		EQUB &20								;minimum acceptable ASCII value
		EQUB &7E								;maximum acceptable ASCII value

.L89A3	  LDA #&2A								;'*'
            JMP OSWRCH								;write to screen
			
.L89A8      LDY #&04
.L89AA      LDA L899E,Y
            STA L0100,Y
            DEY
            BPL L89AA
            LDA #&00
            LDX #&00
            LDY #&01
            JSR OSWORD
            BCS L89BF
            RTS
			
.L89BF      JMP L91F1

;Start of full reset
.L89C2      LDX #&32								;Start with register &32
.L89C4      LDA #&00								;Set to 0
            CPX #&05								;Check if register &5 (LANG/FILE parameters)
            BNE L89D2								;No? Then branch
            LDA romselCopy									;Read current ROM number
            ASL A
            ASL A
            ASL A
            ASL A									;move to upper 4 bits (LANG parameter)
            ORA romselCopy									;Read current ROM number & save to lower 4 bits (FILE parameter)
;	  LDA #&EC								;Force LANG: 14, FILE: 12 in IBOS 1.21 (in place of ORA &F4 in line above)
.L89D2      JSR writeUserReg								;Write to RTC clock User area. X=Addr, A=Data
            DEX
            BPL L89C4
            JSR LA790								;Stop Clock and Initialise RTC registers &00 to &0B
            LDX #&00								;Relocate 256 bytes of code to main memory
.L89DD      LDA L89E9,X
            STA L2800,X
            INX
            BNE L89DD
            JMP L2800								;Then jump to main memory
			
;This code is relocated from IBOS ROM to RAM starting at &2800
.L89E9      LDA romselCopy									;Get current SWR bank number.
            PHA									;Save it
            LDX #&0F								;Start at SWR bank 15
.L89EE      STX romselCopy									;Select memory bank
            STX romsel
            LDA #&80								;Start at address &8000
	  JSR L8A46-L89E9+L2800							;Fill bank with &00 (will try both RAM & ROM) 
            DEX
            BPL L89EE								;Until all RAM banks are wiped.
            LDA #&F0								;Set Private RAM bits (PRVSx) & Shadow RAM Enable (SHEN)
            STA ramselCopy
            STA ramsel
            LDA #&40								;Set Private RAM Enable (PRVEN) & Unset Shadow / Main toggle (MEMSEL)
            STA romselCopy
            STA romsel
            LDA #&30								;Start at shadow address &3000
	  JSR L8A46-L89E9+L2800							;Fill shadow and private memory with &00
            LDA #&FF								;Write &FF to PRVS1 &830C..&830F
            STA prv83+&0C
            STA prv83+&0D
            STA prv83+&0E
            STA prv83+&0F
            LDA #&00								;Unset Private RAM bits (PRVSx) & Shadow RAM Enable (SHEN)
            STA ramselCopy
            STA ramsel
            PLA									;Restore SWR bank
            STA romselCopy
            STA romsel
            LDY #&1E								;Number of entries in lookup table for IntegraB defaults
.L8A2D	  LDX intDefault-L89E9+L2800+&00,Y						;address of relocated intDefault table:		(address for data)
	  LDA intDefault-L89E9+L2800+&01,Y						;address of relocated intDefault table+1:	(data)
            JSR writeUserReg								;Write IntegraB default value to RTC User RAM
            DEY
            DEY
            BPL L8A2D								;Repeat for all 16 values
            LDA #&97								;Write to SHEILA (&FExx)
            LDX #&4E								;Write to SHEILA+&4E (&FE4E)
            LDY #&7F								;Data to be written
            JSR OSBYTE								;Write &7F to SHEILA+&4E (System VIA)
            JMP (RESET)								;Carry out Reset
			
.L8A46	  STA L0000+&01								;This is relocated address &285D
            LDA #&00								;Start at address &8000 or &3000
            STA L0000
            TAY
.L8A4D      LDA #&00								;Store &00
            STA ($00),Y
            INY
            BNE L8A4D
            INC L0000+&01
            LDA L0000+&01
            CMP #&C0
            BNE L8A4D								;Until address is &C000
            RTS

;lookup table for IntegraB defaults - Address (X) / Data (A)
;Read by code at &8834
;For data at addresses &00-&31, data is stored in RTC RAM at location Addr + &0E (RTC RAM &0E-&3F)
;For data at addresses &32 and above, data is stored in private RAM at location &8300 + Addr OR &80.
.intDefault	EQUB &06,&FF								;*INSERT status for ROMS &0F to &08. Default: &FF (All 8 ROMS enabled)
		EQUB &07,&FF								;*INSERT status for ROMS &07 to &00. Default: &FF (All 8 ROMS enabled)
;		EQUB &0A,&E7								;0-2: MODE / 3: SHADOW / 4: TV Interlace / 5-7: TV screen shift. Default was &17. Changed to &E7 in IBOS 1.21
;		EQUB &0B,&20								;0-2: FDRIVE / 3-5: CAPS. Default was &23. Changed to &20 in IBOS 1.21
		EQUB &0A,&17								;0-2: MODE / 3: SHADOW / 4: TV Interlace / 5-7: TV screen shift.
		EQUB &0B,&23								;0-2: FDRIVE / 3-5: CAPS.
		EQUB &0C,&19								;0-7: Keyboard Delay
		EQUB &0D,&05								;0-7: Keyboard Repeat
		EQUB &0E,&0A								;0-7: Printer Ignore
		EQUB &0F,&2D								;0: Tube / 2-4: BAUD / 5-7: Printer
;		EQUB &10,&A1								;0: File system / 4: Boot / 5-7: Data. Default was &A0. Changed to &A1 in IBOS 1.21
		EQUB &10,&A0								;0: File system / 4: Boot / 5-7: Data.
		EQUB &32,&04								;0-2: OSMODE / 3: SHX
;		EQUB &35,&14								;Century - Default was &13 (1900). Changed to &14 (2000) in IBOS 1.21
		EQUB &35,&13								;Century - Default is &13 (1900)
		EQUB &38,&FF
		EQUB &39,&FF
		EQUB userRegPrvPrintBufferStart,&90
		EQUB &7F,&0F								;Bit set if RAM located in 32k bank. Clear if ROM is located in bank. Default is &0F (lowest 4 x 32k banks).

.L8A7B	  PHP
	  SEI
	  JSR PrvEn								;switch in private RAM
            TXA
            STA prv82+&53
            LDA ramselCopy
            ROL A
            PHP
            LDA prv82+&53
            AND #&C0
            CMP #&80
            BNE L8A9F
            PLP
            PHP
            ROR prv83+&3E
            LDA prv82+&53
            AND #&41
            STA prv82+&53
.L8A9F      PLP
            LDA #&00
            ROL A
            STA prv82+&52
            BIT prv82+&53
            BVC L8AB3
            BPL L8AC1
            ASL prv83+&3E
            ROL prv82+&53
.L8AB3      LDA ramselCopy
            ROL A
            ROR prv82+&53
            ROR A
            STA ramselCopy
            STA ramsel
.L8AC1      LDA prv82+&52
            TAX
            JSR PrvDis								;switch out private RAM
            PLP
            RTS
			
;Unrecognised OSBYTE call - Service call &07
;A, X & Y stored in &EF, &F0 & F1 respecively
.service07  LDX #prvOsMode - prv83								;select OSMODE
            JSR readPrivateRam8300X								;read data from Private RAM &83xx (Addr = X, Data = A)
            CMP #&00								;OSMODE 0?
            BNE osbyte6C								;Branch if OSMODE 1-5
            LDA L00EF								;get OSBYTE command
            JMP osbyteA1								;Branch if OSMODE 0 - skip OSBYTE &6C / &72
			
;Test for OSBYTE &6C - Select Shadow/Screen memory for direct access
.osbyte6C	  LDA L00EF								;get OSBYTE command
            CMP #&6C								;OSBYTE &6C - Select Shadow/Screen memory for direct access
            BNE osbyte72
            LDA oswdbtX
            BEQ L8AE4
            LDA #&01
.L8AE4      PHP
            SEI
            ROL ramselCopy
            PHP
            EOR #&01
            ROR A
            LDA ramselCopy
            ROR A
            STA ramselCopy
            STA ramsel
            LDA #&00
.L8AF9      PLP
            ROL A
            EOR #&01
            STA oswdbtX
            PLP
            JMP exitSC								;Exit Service Call
			
;Test for OSBYTE &72 - Specify video memory to use on next MODE change (http://beebwiki.mdfs.net/OSBYTE_%2672)
.osbyte72	  CMP #&72								;OSBYTE &72 - Specify video memory to use on next MODE change
            BNE osbyteA1
            LDA #&EF								;OSBYTE call - write to &27F
            LDX oswdbtX
            BEQ L8B0F								;if '0' then retain '0'
            LDX #&01								;otherwise set to '1'
.L8B0F      LDY #&00
            JSR OSBYTE								;write to &27F
            STX oswdbtX
            JMP exitSC								;Exit Service Call
			
;Test for OSBYTE &A1 - Read configuration RAM/EEPROM
.osbyteA1	  CMP #&A1								;OSBYTE &A1 - Read configuration RAM/EEPROM
            BNE osbyteA2
            PLA
            LDX oswdbtX
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            STA oswdbtY
            PHA
            JMP exitSC								;Exit Service Call
			
;Test for OSBYTE &A2 - Write configuration RAM/EEPROM
.osbyteA2	  CMP #&A2								;OSBYTE &A2 - configuration RAM/EEPROM
            BNE osbyte44
            LDX oswdbtX
            LDA oswdbtY
            JSR writeUserReg								;Write to RTC clock User area. X=Addr, A=Data
            PLA
            LDA oswdbtY
            PHA
            JMP exitSC								;Exit Service Call
			
;Test for OSBYTE &44 - Test sideways RAM presence
.osbyte44	  CMP #&44								;OSBYTE &44 (68) - Test sideways RAM presence
            BNE osbyte45
            JMP L9928
			
;Test for OSBYTE &45 (69) - Test PSEUDO/Absolute usage
.osbyte45	  CMP #&45								;OSBYTE &45 (69) - Test PSEUDO/Absolute usage
            BNE osbyte49
            JMP L995C
			
;Test for OSBYTE &49 (73) - Integra-B calls
.osbyte49	  CMP #&49								;OSBYTE &49 (73) - Integra-B calls
            BEQ L8B50
            JMP exitSCa								;restore service call parameters and exit
			
.L8B50      LDA oswdbtX
            CMP #&FF								;test X for &FF
            BNE L8B63								;if not, branch
            LDA #&49								;otherwise yes, and return &49
            STA oswdbtX
            PLA
            LDA romselCopy
            AND #&0F
            PHA
            JMP exitSC								;Exit Service Call
			
.L8B63      CMP #&FE								;test X for &FE
            BNE L8B6D								;if not, branch
            JSR LB35E								;otherwise yes, and JSR???
            JMP exitSC								;Exit Service Call
			
.L8B6D      LDX #&44								;read data from &8344???
            JSR readPrivateRam8300X								;read data from Private RAM &83xx (Addr = X, Data = A)
            PHA
            STA oswdbtY
            LDA oswdbtX
            LSR A
            LSR A
            AND oswdbtY
            EOR oswdbtX
            AND #&03
            JSR writePrivateRam8300X								;write data to Private RAM &83xx (Addr = X, Data = A)
            LDX #&0B
            CMP #&00
            BNE L8B90
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            AND #&EF
            JMP L8B95
			
.L8B90      JSR rdRTCRAM								;Read data from RTC memory location X into A
            ORA #&10
.L8B95      JSR wrRTCRAM								;Write data from A to RTC memory location X
            PLA
            STA oswdbtX
            JMP exitSC								;Exit Service Call

            LDA vduStatus								;get VDU status   ***missing reference address***
            AND #&EF								;clear bit 4
            STA vduStatus								;store VDU status
            LDA ramselCopy								;get RAMID
            AND #&80								;mask bit 7 - Shadow RAM enable bit
            LSR A
            LSR A
            LSR A									;move to bit 4
            ORA vduStatus								;combine with &00D0
            STA vduStatus								;and store VDU status
.L8BB0      RTS

;Unrecognised OSWORD call - Service call &08
.service08  LDA oswdbtA								;read OSWORD call number

	  CMP #&0E								;OSWORD &0E (14) Read real time clock
	  BNE service08a
	  JMP osword0e
			
.service08a CMP #&42								;OSWORD &42 (66 ) - Sideways RAM transfer
            BNE service08b
            JMP osword42

.service08b CMP #&43								;OSWORD &43 (67 ) - Load/Save into/from sideways RAM	
            BNE service08c
            JMP osword43

.service08c CMP #&49								;OSWORD &49 (73) - Integra-B calls. If the command passed in XY+0 is not &60-&6F the call is ignored and passed on to other ROMs.
            BNE service08d
            TYA
            PHA
            LDY #&00
            LDA (oswdbtX),Y
            TAX
            PLA
            TAY
            TXA
            CMP #&60
            BCC service08d
            CMP #&70
            BCS service08d
            JMP osword49
			
.service08d JMP exitSCa								;restore service call parameters and exit

;*BOOT Command
;The *BOOT parameters are stored in Private RAM at &81xx
;They are copied to *KEY10 (BREAK) and executed on a power on reset
;Checks for ? parameter and prints out details;
;Checks for blank and clears table
.boot       JSR PrvEn								;switch in private RAM
            LDA (L00A8),Y
            CMP #'?'
            BEQ L8C26								;Print *BOOT parameters
            LDA L00A8
            STA osCmdPtr
            LDA L00A9
            STA osCmdPtr + 1
            SEC
            JSR GSINIT
            SEC
            BEQ L8C0C
            LDX #&01
.L8BFE      JSR GSREAD
            BCS L8C0E
            STA prv81,X
            INX									;get next character
            CPX #&F0								;check if parameter is too long
            BNE L8BFE								;loop if not too long
            CLC									;otherwise set error flag
.L8C0C      LDX #&00								;wipe parameter
.L8C0E      STX prv81
            JSR PrvDis								;switch out private RAM
            BCC L8C19								;check for error
            JMP exitSC								;Exit Service Call
			
.L8C19      JSR raiseError								;Goto error handling, where calling address is pulled from stack

		EQUB &FD
		EQUS "Too long", &00

.L8C26      LDX prv81
            BEQ L8C39
            LDX #&01
.L8C2D      LDA prv81,X
            JSR L8C3C
            INX
            CPX prv81
            BNE L8C2D
.L8C39      JMP L8E07

.L8C3C      CMP #&80
            BCC L8C4C
            PHA
            LDA #&7C								;CHR$&7C
            JSR OSWRCH								;write to screen
            LDA #'!'								;'!'
            JSR OSWRCH								;write to screen
            PLA
.L8C4C      AND #&7F
            CMP #&20
            BCS L8C61
.L8C52      AND #&3F
.L8C54      PHA
            LDA #&7C								;CHR$&7C
            JSR OSWRCH								;write to screen
            PLA
            CMP #&20
            BCS L8C6D
            ORA #&40
.L8C61      CMP #&7F
            BEQ L8C52
            CMP #&22
            BEQ L8C54
            CMP #&7C
            BEQ L8C54
.L8C6D      JMP OSWRCH

;*PURGE Command
.purge
{
            JSR L8699
            BCC L8C8F
            LDA (L00A8),Y
            CMP #&3F
            BNE L8C86
            JSR L83EC
            LDX #&47
            JSR readPrivateRam8300X								;read data from Private RAM &83xx (Addr = X, Data = A)
            JMP L8FA3
			
.L8C86      JSR PrvEn								;switch in private RAM
            JSR purgePrintBuffer
            JMP L8E0A

.L8C8F      LDX #&47
            JSR writePrivateRam8300X								;write data to Private RAM &83xx (Addr = X, Data = A)
            JMP exitSC								;Exit Service Call
}
			
;*BUFFER Command
;Note Buffer does not work in OSMODE 0
.buffer
{
            JSR PrvEn								;switch in private RAM
            LDA prvOsMode								;read OSMODE
            BNE L8CAE								;error if OSMODE 0, otherwise continue
            JSR raiseError								;Goto error handling, where calling address is pulled from stack

		EQUB &80
		EQUS "No Buffer!", &00

.L8CAE      JSR convertIntegerDefaultDecimal
            BCC L8CC6
            LDA (L00A8),Y								;get byte from keyboard buffer SFTODO: command argument, not keyboard buffer?
            CMP #'#'								;check for '#'
            BEQ L8D07								;set buffer based on manually entered bank numbers
            CMP #'?'								;check for '?'
            BNE L8CC0								;identify free banks and set buffer based on number of banks requested by user
            JMP L8DCA								;report number of banks set
			
.L8CC0      JSR PrvDis								;switch out private RAM
            JMP syntaxError
			
.L8CC6      CMP #&05
            BCC L8CCD
            JMP badParameter
			
.L8CCD      PHA
            JSR L8E6C								;check if print buffer is empty, and error if something is already in the buffer.
            JSR L8D37								;unassign RAM banks from *BUFFER by setting prv83+&18 thru prv83+&1A to &FF
            LDX #&00
            LDY #&00								;starting at SWRAM bank 0
.L8CD8      JSR L8E10								;test for SWRAM at bank Y
            BCS L8CE6
            TYA
            STA prvPrintBufferBankList,X								;store RAM bank number in Private memory
            INX									;increment counter for number of RAM banks found
            CPX #&04								;until 4 banks are found
            BEQ L8CEB
.L8CE6      INY
            CPY #&10								;until all 16 banks have been tested
            BNE L8CD8
.L8CEB      PLA
            BNE L8CF4
            JSR L8D37								;unassign RAM banks from *BUFFER by setting prv83+&18 thru prv83+&1A to &FF
            JMP L8D01
			
.L8CF4      TAX
            LDA #&FF
.L8CF7      CPX #&04
            BCS L8D01
            STA prvPrintBufferBankList,X
            INX
            BNE L8CF7
.L8D01      JSR L8D5A
            JMP L8DCA
			
.L8D07      JSR L8E6C
            JSR L8D37								;unassign RAM banks from *BUFFER by setting prv83+&18 thru prv83+&1A to &FF
            INY
            LDX #&00
            STX L00AC
.L8D12      JSR parseBankNumber
            STY L00AD
            BCS L8D31
            TAY
            JSR L8E10								;test for SWRAM at bank Y
            TYA
            BCS L8D2C
            LDX L00AC
            STA prvPrintBufferBankList,X
            INX
            STX L00AC
            CPX #&04
            BEQ L8D31
.L8D2C      LDY L00AD
            JMP L8D12
			
.L8D31      JSR L8D5A
            JMP L8DCA
			
.L8D37      LDA #&FF								;unassign RAM banks from *BUFFER
            STA prvPrintBufferBankList
            STA prv83+&19
            STA prv83+&1A
            STA prv83+&1B
            RTS
}
			
.L8D46      LDA romselCopy
            AND #&0F
            ORA #&40
            STA prvPrintBufferBankList
            LDA #&FF
            STA prvPrintBufferBankList + 1
            STA prvPrintBufferBankList + 2
            STA prvPrintBufferBankList + 3
.L8D5A      LDA prvPrintBufferBankList
            CMP #&FF
            BEQ L8D46
            AND #&F0
            CMP #&40
            BNE bufferInSidewaysRam
            ; Buffer is in private RAM, not sideways RAM.
            JSR sanitisePrvPrintBufferStart
            STA prvPrintBufferBankStart
            LDA #&B0
            STA prvPrintBufferBankEnd
            LDA #&00
            STA prvPrintBufferFirstBankIndex
            STA prv82+&0F
            STA prvPrintBufferSizeLow
            STA prvPrintBufferSizeHigh
            SEC
            LDA prvPrintBufferBankEnd
            SBC prvPrintBufferBankStart
            STA prvPrintBufferSizeMid
            JMP purgePrintBuffer

.bufferInSidewaysRam
.L8D8D      LDA #&00
            STA prvPrintBufferSizeLow
            STA prvPrintBufferSizeMid
            STA prvPrintBufferSizeHigh
            TAX
.L8D99      LDA prvPrintBufferBankList,X
            BMI L8DB5
            CLC
            LDA prvPrintBufferSizeMid
            ADC #&40
            STA prvPrintBufferSizeMid
            LDA prvPrintBufferSizeHigh
            ADC #&00
            STA prvPrintBufferSizeHigh
            INX
            CPX #&04
            BNE L8D99
            DEX
.L8DB5      LDA #&80
            STA prvPrintBufferBankStart
            LDA #&00
            STA prvPrintBufferFirstBankIndex
            LDA #&C0
            STA prvPrintBufferBankEnd
            STX prv82+&0F
            JMP purgePrintBuffer
			
.L8DCA      LDA prvPrintBufferSizeHigh
            LSR A
            LDA prvPrintBufferSizeMid
            ROR A
            ROR A
            SEC									;left justify (ignore leading 0s)
            JSR printADecimal								;Convert binary number to numeric characters and write characters to screen
            LDA prvPrintBufferBankList
            AND #&F0
            CMP #&40
            BNE L8DE8
            LDX #&00
            JSR L8E8C								;write 'k in Private RAM'
            JMP L8E07								;and finish
			
.L8DE8      LDX #&01								;starting with the first RAM bank
            JSR L8E8C								;write 'k in Sideways RAM '
            LDY #&00
.L8DEF      LDA prvPrintBufferBankList,Y								;get RAM bank number from Private memory
            BMI L8E02								;if nothing in private memory then finish, otherwise
            SEC									;left justify (ignore leading 0s)
            JSR printADecimal								;Convert binary number to numeric characters and write characters to screen
            LDA #&2C								;','
            JSR OSWRCH								;write to screen
            INY									;repeat
            CPY #&04								;upto 4 times for maximum of 4 banks
            BNE L8DEF
.L8E02      LDA #&7F								;delete the last ',' that was just printed
            JSR OSWRCH								;write to screen
.L8E07      JSR OSNEWL
.L8E0A      JSR PrvDis								;switch out private RAM
            JMP exitSC								;Exit Service Call

;Test for SWRAM			
.L8E10      TXA
            PHA
            LDA L02A1,Y								;read ROM Type from ROM Type Table
            BNE L8E68								;exit if not 0
            LDA prv83+&2C,Y								;read ROM Type from Private RAM backup
            BNE L8E68								;exit if not 0
            PHP
            SEI
            LDA #&00
            STA ramRomAccessSubroutineVariableInsn + 1
            LDA #&80
            STA ramRomAccessSubroutineVariableInsn + 2
            LDA #opcodeLdaAbs
            STA ramRomAccessSubroutineVariableInsn
            JSR ramRomAccessSubroutine							;switch to ROM Bank Y and read value of &8000 to A
            EOR #&FF								;EOR with &FF
            TAX									;and write back to &8000
            LDA #opcodeStaAbs
            STA ramRomAccessSubroutineVariableInsn
            TXA
            JSR ramRomAccessSubroutine							;switch to ROM Bank Y and write value of A to &8000
            TAX
            LDA #opcodeCmpAbs
            STA ramRomAccessSubroutineVariableInsn
            TXA
            JSR ramRomAccessSubroutine							;switch to ROM Bank Y and compare value of &8000 with A
            SEC
            BNE L8E4A
            CLC
.L8E4A      TAX
            PLA
            BCS L8E54
            AND #&FE
            PHA
            JMP L8E57
			
.L8E54      ORA #&01
            PHA
.L8E57      TXA									;restore the contents of ROM Bank Y &8000
            EOR #&FF								;EOR with &FF
            TAX									;and write back to &8000
            LDA #opcodeStaAbs
            STA ramRomAccessSubroutineVariableInsn
            TXA
            JSR ramRomAccessSubroutine
            PLP
            JMP L8E69
			
.L8E68      SEC
.L8E69      PLA
            TAX
            RTS

;Check if printer buffer is empty			
.L8E6C      PHA
            TYA
            PHA
            LDA #&98								;Examine Buffer status
            LDX #&03								;Select buffer 3: Printer buffer
            LDY #&00
            JSR OSBYTE								;Examine Buffer 3
            PLA
            TAY
            PLA
            BCC L8E7E								;Buffer not empty: error
            RTS
			
.L8E7E      JSR raiseError								;Goto error handling, where calling address is pulled from stack

		EQUB &80
		EQUS "Printing!", &00

.L8E8C      CPX #&00								;If X=0 then
            BEQ L8E92								;select Private RAM message
            LDX #&11								;else select Sideways RAM message
.L8E92      LDA L8E9E,X								;Get Character from lookup table
            BEQ L8E9D								;Exit if 0
            JSR OSWRCH								;Print Character
            INX									;Next Character
            BNE L8E92								;Loop
.L8E9D      RTS

.L8E9E		EQUS "k in Private RAM", &00
		EQUS "k in Sideways RAM ", &00

;*OSMODE Command
.osmode      JSR convertIntegerDefaultDecimal
            BCC L8ED0
            LDA (L00A8),Y
            CMP #&3F
            BEQ L8ED6
            JMP syntaxError
			
.L8ED0      JSR L8EE5
            JMP exitSC								;Exit Service Call
			
.L8ED6      JSR L83EC
            LDX #prvOsMode - prv83								;select OSMODE
            JSR readPrivateRam8300X								;read data from Private RAM &83xx (Addr = X, Data = A)
.L8EDE      SEC
            JSR printADecimal								;Convert binary number to numeric characters and write characters to screen
            JMP L8E07								;new line, exit out of private RAM and exit service call
			
.L8EE5      CMP #&00
            BEQ L8F01
            CMP #&06
            BCS L8EFE
            PHA
            JSR PrvEn								;switch in private RAM
            LDA prvOsMode								;read OSMODE
            BEQ L8F17
.L8EF6      PLA
            STA prvOsMode								;write OSMODE
.L8EFA      JSR PrvDis								;switch out private RAM
            RTS
			
			
.L8EFE      JMP badParameter

.L8F01      JSR PrvEn								;switch in private RAM
            LDA prvOsMode								;read OSMODE
            BEQ L8EFA
            JSR L8E6C
            LDA #&00
            STA prvOsMode								;write OSMODE
            JSR SFTODOZZ
            JMP L8EFA
			
.L8F17      JSR L8E6C
            PLA
            STA prvOsMode								;write OSMODE
            JSR LBC98
            JMP L8EFA
			
;*SHADOW Command
.shadow
{
	  JSR convertIntegerDefaultDecimal
            BCC L8F41
            LDA (L00A8),Y								;get next character from command parameter
            CMP #'?'								;check for '='
            BEQ L8F38								;branch if set
            CMP #&0D								;check for no parameters
            BNE L8F47
            LDA #&00								;if no parameters then
            JMP L8F41								;set &27F to 0
			
.L8F38      JSR L83EC
            LDA osShadowRamFlag
            JMP L8EDE								;print shadow number and exit service call
			
.L8F41      STA osShadowRamFlag
            JMP exitSC								;Exit Service Call
}

.L8F47      JMP syntaxError

;*SHX Command
.shx
{
            JSR L8699
            BCC L8F60
            LDA (L00A8),Y
            CMP #'?'
            BNE L8F47
            JSR L83EC
            LDX #&3D								;select SHX register (&08: On, &FF: Off)
            JSR readPrivateRam8300X								;read data from Private RAM &83xx (Addr = X, Data = A)
            JMP L8FA3
			
.L8F60      LDX #&3D								;select SHX register (&08: On, &FF: Off)
            JSR writePrivateRam8300X								;write data to Private RAM &83xx (Addr = X, Data = A)
            JMP exitSC								;Exit Service Call
}
			
;*CSAVE Command
.csave
{
            LDA #&80								;open file for output
            JSR L922B								;get address of file name and open file
            TAY									;move file handle to Y
            LDX #&00								;start at RTC clock User area 0
.L8F70      JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            JSR OSBPUT								;write data in A to file handle Y
            INX									;next byte
            BPL L8F70								;for 128 bytes
            BMI L8F8C								;close file and exit
}

;*CLOAD Command
.cload      LDA #&40								;open file for input
            JSR L922B								;get address of file name and open file
            TAY									;move file handle to Y
            LDX #&00								;start at RTC clock User area 0
.L8F83      JSR OSBGET								;read data from file handle Y into A
            JSR writeUserReg								;Write to RTC clock User area. X=Addr, A=Data
            INX									;get next byte
            BPL L8F83								;for 128 bytes

.L8F8C      JSR L9268								;close file with file handle at &A8
            JMP exitSC								;exit Service Call

;*TUBE Command
.tube       JSR L8699
            BCC L8FAF
            LDA (L00A8),Y
            CMP #&3F
            BNE L8FAC
            JSR L83EC
            LDA tubePresenceFlag
.L8FA3      JSR L86C8
            JSR OSNEWL
.L8FA9      JMP exitSC								;Exit Service Call

.L8FAC      JMP syntaxError

.L8FAF      BNE L8FF1
            BIT tubePresenceFlag								;check for Tube - &00: not present, &ff: present
            BPL L8FA9
            LDA L028C
            BPL L8FBF
            LDA romselCopy
            AND #&0F
.L8FBF      PHA
            JSR L8FC8
            PLA
            TAX
            JMP L90F4
			
			
.L8FC8      LDA #&00
            LDX #&40
            JSR writePrivateRam8300X								;write data to Private RAM &83xx (Addr = X, Data = A)
            LDA #&FF
            LDX #&41
            JSR writePrivateRam8300X								;write data to Private RAM &83xx (Addr = X, Data = A)
            LDA #&00
            STA tubePresenceFlag
            LDA #&00
            LDX #&A8
            LDY #&00
            JSR OSARGS
            TAY
            LDX #&12
            JSR L9050
            LDA #&00
            LDX #&41
            JMP writePrivateRam8300X								;write data to Private RAM &83xx (Addr = X, Data = A)
			
.L8FF1      LDA #&81
            STA SHEILA+&E0
            LDA SHEILA+&E0
            LSR A
            BCS L9009								;Tube exists - Initialise
            JSR raiseError								;Goto error handling, where calling address is pulled from stack

	  EQUB &80
	  EQUS "No Tube!", &00

;Initialise Tube
.L9009      BIT tubePresenceFlag								;check for Tube - &00: not present, &ff: present
            BMI L8FA9
            LDA #&FF
            LDX #&40
            JSR writePrivateRam8300X								;write data to Private RAM &83xx (Addr = X, Data = A)
            LDX #&41
            JSR writePrivateRam8300X								;write data to Private RAM &83xx (Addr = X, Data = A)
            LDX #&FF								;service type &FF - tube system main initialisation
            LDY #&00
            JSR L9050								;issue paged ROM service request
            LDA #&FF
            STA tubePresenceFlag
            LDX #&FE								;service type &FE - tube system post initialisation
            LDY #&00
            JSR L9050								;issue paged ROM service request
            LDA #&00
            LDX #&A8
            LDY #&00
            JSR OSARGS
            TAY
            LDX #&12								;service type &12 - initialise file system
            JSR L9050								;issue paged ROM service request
            LDA #&00
            LDX #&41
            JSR writePrivateRam8300X								;write data to Private RAM &83xx (Addr = X, Data = A)
            LDA #&7F
.L9045      BIT SHEILA+&E2
            BVC L9045
            STA SHEILA+&E3
            JMP L0032
			
.L9050      LDA #&8F								;issue paged ROM service request
            JMP OSBYTE								;execute paged ROM service request
			
; Page in PRVS1.
; SFTODO: Is there any chance of saving space by sharing some code with the
; similar pageInPrvs81?
.pageInPrvs1
; SFTODO: I'd like to get rid of the PrvEn label and just use pageInPrvs1 but
; won't do it just yet, as I don't fully understand the model the code is using
; to manage paging private RAM in/out.
.PrvEn      PHA
            LDA ramselCopy
            ORA #ramselPrvs1
            STA ramselCopy
            STA ramsel
            LDA romselCopy
            ORA #romselPrvEn
            STA romselCopy
            STA romsel
            PLA
            RTS
			


; Page out private RAM.
; SFTODO: This clears PRVS1 in RAMSEL, but is that actually necessary? If PRVEN is
; clear none of the private RAM is accessible. Do we ever just set PRVEN and rely
; on RAMSEL already having some of PRVS1/4/8 set? The name "pageOutPrv1" is chosen
; to try to reflect this, but it's a bit misleading as we are paging out the *whole*
; private 12K.
; SFTODO: I'm tempted to get rid of the PrvDis label but I'll leave it for now
.pageOutPrv1
.PrvDis	  PHA
            LDA romselCopy
            NOT_AND romselPrvEn                                                                     ;Clear PrvEn
            STA romselCopy
            STA romsel
            LDA ramselCopy
            NOT_AND ramselPrvs1							;Clear PRVS1
            STA ramselCopy
            STA ramsel
            PLA
            RTS
			

{
;execute '*S*' command
;switches to shadow, executes command, then switches back out of shadow?
.^commandS
.L9083      CLV
            SEC
            BCS L9088

;execute '*X*' command
;switches from shadow, executes command, then switches back to shadow
.^commandX
.L9087      CLC
.L9088      PHP
            INY
            INY
            JSR findNextCharAfterSpace								;find next character. offset stored in Y
            CLC
            TYA
            ADC L00A8
            PHA
            LDA L00A9
            ADC #&00
            PHA
            TSX
            LDA L0103,X
            LSR A
            BCS L90A7
            LDX #&80
            JSR L8A7B
            JMP L90DE
			
.L90A7      LDA #&04
            JSR L8EE5
            LDA #&00
            STA osShadowRamFlag
            LDX #&3D								;select SHX register
            LDA #&FF								;store &FF to &833D (&08: SHX On, &FF: SHX Off)
            JSR writePrivateRam8300X								;write data to Private RAM &83xx (Addr = X, Data = A)
            LDA #&16								;change screen mode
            JSR OSWRCH
            LDA currentMode								;current screen mode
            JSR OSWRCH
            BIT tubePresenceFlag								;check for Tube - &00: not present, &ff: present
            BPL L90DE
            JSR L8FC8
            TSX
            LDA L0103,X
            ORA #&40
            STA L0103,X
            LDA romselCopy
            AND #&0F
            STA L028C
            JSR L88D7
.L90DE      PLA
            TAY
            PLA
            TAX
            JSR OSCLI
            PLP
            BCS L90F0
            LDX #&C0
            JSR L8A7B
.L90ED      JMP exitSC								;Exit Service Call

.L90F0      BVC L90ED
            FALLTHROUGH_TO nle
}

;*NLE Command
.nle	  LDX romselCopy									;Get current ROM number
.L90F4      LDA #&8E
            JMP OSBYTE								;Enter IBOS as a language ROM
			
;*GOIO Command
.goio	  LDA (L00A8),Y
            CMP #&28
            PHP
            BNE L9101
            INY
.L9101      JSR convertIntegerDefaultHex
            BCC L9109
            JMP syntaxError
			
.L9109      LDA (L00A8),Y
            CMP #&29
            BNE L9110
            INY
.L9110      JSR findNextCharAfterSpace								;find next character. offset stored in Y
            LDA #&4C
            PLP
            BNE L911A
            LDA #&6C
.L911A      STA L00AF
            CLC
            TYA
            ADC L00A8
            TAX
            LDA L00A9
            ADC #&00
            TAY
            LDA #&01
            JSR L00AF
            JMP exitSC								;Exit Service Call
			
;*APPEND Command
.append	  LDA #&C0								;open file for update
            JSR L922B								;get address of file name and open file
            LDA #&00
            STA L00AA
            JSR PrvEn								;switch in private RAM
.L913A      JSR OSNEWL
            LDA #&7F
            LDX L00A8
            JSR OSBYTE
            CPX #&00
            BNE L9165
            JSR L91AC
.L914B      LDY L00A8
            JSR OSBGET
            BCS L9165
            CMP #&0D
            BEQ L913A
            CMP #&20
            BCC L914B
            CMP #&7F
            BCS L914B
            JSR OSWRCH
            BNE L914B
            BEQ L913A
.L9165      JSR L91AC
            LDY #&04
.L916A      LDA L91A7,Y
            STA L00AB,Y
            DEY
            BPL L916A
            LDX #&AB
            LDY #&00
            LDA #&00
            JSR OSWORD								;read line from input
            BCS L9196
            INY
            STY L00A9
            LDX #&00
.L9183      LDA prv80+&00,X
            LDY L00A8
            JSR OSBPUT
            CMP #&0D
            BEQ L9165
            INX
            CPX L00A9
            BNE L9183
            BEQ L9165
.L9196      LDA #&7E
            JSR OSBYTE
            JSR PrvDis								;switch out private RAM
            JSR L9268								;close file with file handle at &A8
            JSR OSNEWL
            JMP L8E07
			

;OSWORD A=&0, Read line from input - Parameter block
.L91A7	  EQUW prv80								;buffer address
	  EQUB &FF								;maximum line length
	  EQUB &20								;minimum acceptable ASCII value
	  EQUB &7E								;maximum acceptable ASCII value
	
{
.^L91AC      INC L00AA
            LDA L00AA
            CLC
            JSR printADecimal								;Convert binary number to numeric characters and write characters to screen
            LDA #':'
            JSR OSWRCH								;write to screen
.^printSpace
.L91B9      LDA #' '
            JMP OSWRCH								;write to screen
}
			
;*PRINT Command
.print      LDA #&40								;open file for input
            JSR L922B								;get address of file name and open file
            LDA #&EC
            LDX #&00
            LDY #&FF
            JSR OSBYTE
            STA L00A9
            LDA #&03
            LDX #&1A
            LDY #&00
            JSR OSBYTE
.L91D7      BIT L00FF
            BMI L91EE
            LDY L00A8
            JSR OSBGET
            BCS L91E8
            JSR OSASCI
            JMP L91D7
			
.L91E8      JSR L9201
            JMP exitSC								;Exit Service Call
			
.L91EE      JSR L9201
.L91F1      LDA #&7E
            JSR OSBYTE
            JSR raiseError								;Goto error handling, where calling address is pulled from stack

			EQUB &11
			EQUS "Escape", &00

.L9201      LDA #&03
            LDX L00A9
            LDY #&00
            JSR OSBYTE
            JMP L9268								;close file with file handle at &A8
			
;*SPOOLON Command
.spool      LDA #&C0								;open file for update
            JSR L922B								;get address of file name and open file
            TAY
            LDX L00AB
            LDA #&02
            JSR OSARGS
            LDA #&01
            JSR OSARGS
            LDA #&C7
            LDX L00A8
            LDY #&00
            JSR OSBYTE
            JMP exitSC								;Exit Service Call
			
			
;get start and end offset of file name, store at Y & X
;convert file name offset to address of file name and store at location defined by X & Y
;then open file with file name at location defined by X & Y
.L922B      PHA									;save file mode: input (&40) / output (&80) / update (&C0)
            JSR L9247								;get start and end of file name offset and store in Y & X
            CLC
            TYA									;offset to file name
            ADC L00A8								;input buffer low address
            TAX									;and store in X (low byte of address of file name)
            LDA #&00
            ADC L00A9								;get input buffer high address and increment if low byte carried
            TAY									;and store in Y (high byte of address of file name)
            PLA									;recover file mode: input (&40) / output (&80) / update (&C0)
            JSR OSFIND								;and open file
            CMP #&00								;has error occurred?
            BNE L9244								;no error, so save file handle and exit
            JMP errorNotFound								;otherwise error.
			
.L9244      STA L00A8								;save file handle to &A8
            RTS									;and return
			
			
;get start and end of file name offset and store in Y & X
.L9247      JSR findNextCharAfterSpace								;find next character. offset stored in Y
            LDA (L00A8),Y								;read character
            CMP #&0D								;CR?
            BNE L9253								;not CR, so jump
.L9250      JMP syntaxError								;no file name, so error with 'Syntax:'

.L9253      TYA
            PHA
.L9255      LDA (L00A8),Y								;read character
            CMP #&20								;check for ' '
            BEQ L9262								;ok. end of file name
            CMP #&0D								;check for CR
            BEQ L9262								;ok. end of file name
            INY									;otherwise get next character
            BNE L9255								;loop
.L9262      TYA
            TAX
            INX									;end of file name offset
            PLA
            TAY									;start of file name offset
            RTS
			
			
;Close file with file handle at &A8
.L9268      LDA #osfindClose
            LDY L00A8
            JMP OSFIND
			
;*CREATE Command
.create		JSR L9247
            CLC
            TYA
            ADC L00A8
            STA L02EE
            LDA L00A9
            ADC #&00
            STA L02EF
            LDA #&00
            STA L02F8
            STA L02F9
            STA L02FA
            STA L02FB
            TXA
            TAY
            JSR convertIntegerDefaultHex
            BCS L9250
            LDA L00B0
            STA L02FC
            LDA L00B1
            STA L02FD
            LDA L00B2
            STA L02FE
            LDA L00B3
            STA L02FF
            LDA #&07
            LDX #&EE
            LDY #&02
            JSR OSFILE
            JMP exitSC								;Exit Service Call

; *CONFIGURE and *STATUS simply issue the corresponding service calls, so the
; bulk of their implementation is in the service call handlers. This means that
; third-party ROMs which support these service calls will get a chance to add
; their own *CONFIGURE and *STATUS options, just as they could on a Master.
{
;*CONFIGURE Command
.^config    LDX #serviceConfigure
            BNE L92BB

;*STATUS Command
.^status	  LDX #serviceStatus
.L92BB      JSR findNextCharAfterSpace							;find next character. offset stored in Y
            LDA #&FF								;load &FF
            PHA									;and store
            LDA (transientCmdPtr),Y							;read character
            CMP #vduCr								;check for end of line
            BNE L92CB								;branch if not end of line
            PLA									;pull &FF
            LDA #&00								;load &00 instead
            PHA									;and store
.L92CB      TXA									;move *CONF (*&28) / *STAT (*&29) to A
            PHA									;and store
            LDA transientCmdPtr							;copy command location LSB
            STA osCmdPtr								;to &F2
            LDA transientCmdPtr + 1							;copy command location MSB
            STA osCmdPtr + 1								;to &F3
            PLA									;pull *CONF (*&28) / *STAT (*&29)
            TAX									;and transfer to X
            LDA #osbyteIssueServiceRequest
            JSR OSBYTE
            PLA
            BEQ exitSCIndirect
	  ; SFTODO: Can X be modified by the service call? beebwiki suggests not, but maybe we're extending the protocol or I'm missing something? Documentation on these service calls seems a bit thin on the ground.
            CPX #&00
            BEQ exitSCIndirect
.^badParameter
.L92E3      JSR raiseError								;Goto error handling, where calling address is pulled from stack

	  EQUB &FE
	  EQUS "Bad parameter", &00

.exitSCIndirect
            JMP exitSC								;Exit Service Call
}

; SFTODO: This has only one caller
; Check next two characters of command line:
; "NO" => C clear, transientConfigPrefix=1, Y advanced past "NO"
; "SH" => C clear, transientConfigPrefix=2, Y advanced past "SH"
; otherwise C set, transientConfigPrefix=0, Y preserved
.parseNoSh
{
.L92F8      TYA
            PHA
            LDA (transientCmdPtr),Y
            AND #&DF
            CMP #'N'
            BNE L9313
            INY
            LDA (transientCmdPtr),Y
            AND #&DF
            CMP #'O'
            BNE L9326
            INY
            LDA #&01
.^L930E     STA transientConfigPrefix
            PLA
            CLC
            RTS
			
.L9313      CMP #'S'
            BNE L9326
            INY
            LDA (transientCmdPtr),Y
            AND #&DF
            CMP #'H'
            BNE L9326
            INY
            LDA #&02
            JMP L930E
			
.L9326      LDA #&00
            STA transientConfigPrefix
            PLA
            TAY
            SEC
            RTS
}

.L932E      JSR L9337
            JSR L83F2
            JMP OSNEWL
			
.L9337      CMP #&00
            BNE L933C
            RTS

.L933C      CMP #&02								;If &02 then write 'SH' otherwise write 'NO' in front of CAPS
            BEQ L934A
            LDA #&4E								;N
            JSR OSWRCH
            LDA #&4F								;O
            JMP OSWRCH
			
.L934A      LDA #&53								;S
            JSR OSWRCH
            LDA #&48								;H
            JMP OSWRCH

;*Configure paramters are stored using the following format
;EQUB Register,Start Bit,Number of Bits
.ConfParBit	EQUB &05,&00,&04							;FILE ->	  &05 Bits 0..3
		EQUB &05,&04,&04							;LANG ->	  &05 Bits 4..7
		EQUB &0F,&02,&03							;BAUD ->	  &0F Bits 2..4
		EQUB &10,&05,&03							;DATA ->	  &10 Bits 5..7
		EQUB &0B,&00,&03							;FDRIVE ->  &0B Bits 0..2
		EQUB &0F,&05,&03							;PRINTER -> &0F Bits 5..7
		EQUB &0E,&00,&00							;IGNORE ->  &0E Bits 0..7
		EQUB &0C,&00,&00							;DELAY ->	  &0C Bits 0..7
		EQUB &0D,&00,&00							;REPEAT ->  &0D Bits 0..7
		EQUB &0B,&03,&03							;CAPS ->	  &0B Bits 3..5
		EQUB &0A,&04,&04							;TV ->	  &0A Bits 4..7
		EQUB &0A,&00,&04							;MODE ->	  &0A Bits 0..3
		EQUB &0F,&00,&01							;TUBE ->	  &0F Bit  0
		EQUB &10,&04,&81							;BOOT ->	  &10 Bit  4
		EQUB userRegOsModeShx,&03,&81							;SHX ->	  &32 Bit  3
		EQUB userRegOsModeShx,&00,&03							;OSMODE ->  &32 Bits 0..2
		EQUB &33,&00,&06							;ALARM ->	  &33 Bits 0..5

;*CONFIGURE / *STATUS Options
.ConfTypTbl	EQUW Conf0-1							;FILE <0-15>(D/N)		Type 0:
		EQUW Conf1-1							;LANG <0-15>		Type 1: Number starting 0
		EQUW Conf2-1							;BAUD <1-8>		Type 2:
		EQUW Conf1-1							;DATA <0-7>		Type 1: Number starting 0
		EQUW Conf1-1							;FDRIVE <0-7>		Type 1: Number starting 0
		EQUW Conf1-1							;PRINTER <0-4>		Type 1: Number starting 0
		EQUW Conf1-1							;IGNORE <0-255>		Type 1: Number starting 0
		EQUW Conf1-1							;DELAY <0-255>		Type 1: Number starting 0
		EQUW Conf1-1							;REPEAT <0-255>		Type 1: Number starting 0
		EQUW Conf3-1							;CAPS /NOCAPS/SHCAPS	Type 3: 
		EQUW Conf4-1							;TV <0-255>,<0-1>		Type 4: 
		EQUW Conf5-1							;MODE (<0-7>/<128-135>)	Type 5: 
		EQUW Conf6-1							;TUBE /NOTUBE		Type 6: Optional NO Prefix
		EQUW Conf6-1							;BOOT /NOBOOT		Type 6: Optional NO Prefix
		EQUW Conf6-1							;SHX /NOSHX		Type 6: Optional NO Prefix
		EQUW Conf1-1							;OSMODE	<0-4>		Type 1: Number starting 0
		EQUW Conf1-1							;ALARM <0-63>		Type 1: Number starting 0
	
.L93A9		EQUB &FF,&01,&03,&07
		EQUB &0F,&1F,&3F,&7F


.L93B1      CPX #&00
            BEQ L93B9
.L93B5      ASL A
            DEX
            BNE L93B5
.L93B9      RTS

.L93BA      CPX #&00
            BEQ L93C2
.L93BE      LSR A
            DEX
            BNE L93BE
.L93C2      RTS

.setYToTransientConfIdxTimes3
{
.L93C3      LDA transientConfIdx
            ASL A
            ADC transientConfIdx
            TAY
            RTS
}

.L93CA      LDA ConfParBit+2,Y
            AND #&7F
            TAX
            LDA L93A9,X
            STA L00BC
            LDA ConfParBit+1,Y
            TAX
            LDA L00BC
            JSR L93B1
            STA L00BC
            RTS

.L93E1      STA transientConfigPrefix
.L93E3      JSR setYToTransientConfIdxTimes3
            JSR L93CA
            LDA ConfParBit+1,Y
            TAX
            LDA transientConfigPrefix
            JSR L93B1
            AND L00BC
            STA transientConfigPrefix
            LDA L00BC
            EOR #&FF
            STA L00BC
            LDA ConfParBit,Y
            TAX
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            AND L00BC
            ORA transientConfigPrefix
            JMP writeUserReg							;Write to RTC clock User area. X=Addr, A=Data
			
.L940A      JSR setYToTransientConfIdxTimes3
            JSR L93CA
            LDA ConfParBit,Y
            TAX
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            AND L00BC
            STA transientConfigPrefix
            LDA ConfParBit+1,Y
            TAX
            LDA transientConfigPrefix
            JSR L93BA
            STA transientConfigPrefix
            RTS
			
; SFTODO: This code saves transientConfIdx (&AA) across call to L83F2, but it superficially looks as though L83F2 preserves it itself, so the code to preserve here may be redundant.
.L9427      LDA transientConfIdx
            PHA
            JSR L83F2
            PLA
            STA transientConfIdx
            JSR L940A
            LDA transientConfigPrefix
            RTS

{
;Service call &29: *STATUS Command
.^service29 CLC
            BCC L943A

;Service call &28: *CONFIGURE Command
.^service28 SEC
.L943A      PHP
            JSR setTransientCmdPtr
            LDA (transientCmdPtr),Y
            CMP #vduCr
            BNE optionSpecified
	  ; There's no option specified.
            PLP
            BCC statusAll
	  ; This is *CONFIGURE with no option, so show the supported options.
            LDA #&05 ; SFTODO: magic constant
            JSR ibosRef
            JSR L83A9 ; SFTODO: I suspect this is a kind of help-display-using-table routine but not looked at it yet
            JMP exitSCa								;restore service call parameters and exit
			
.optionSpecified
            LDA #&00
            STA transientConfigPrefix
            JSR ConfRef
            JSR searchCmdTbl
            BCC optionRecognised
            TAY
            JSR parseNoSh
            BCS notNoSh
            TYA
            JSR ConfRef
            JSR searchCmdTbl
            BCC optionRecognised
.notNoSh    PLP
            JMP exitSCa								;restore service call parameters and exit
			
.optionRecognised
	  JSR findNextCharAfterSpace							;find next character. offset stored in Y
            PLP
            JSR jmpConfTypTblX
            JMP exitSC								;Exit Service Call
			
; Jump to the code at ConfTypTbl[X]; C is preserved, as it is used to indicate
; *STATUS (clear) or *CONFIGURE (set).
.jmpConfTypTblX
            PHP
            STX transientConfIdx
            TXA
            ASL A
            TAX
            PLP
            LDA ConfTypTbl+1,X
            PHA
            LDA ConfTypTbl,X
            PHA
            RTS
			
.statusAll  LDX #&00
.L948D      TXA
            PHA
            TYA
            PHA
            CLC ; *STATUS
            JSR jmpConfTypTblX
            PLA
            TAY
            PLA
            TAX
            INX
            CPX ConfTbla								;number of *CONFIGURE options
            BNE L948D
            JMP exitSCa								;restore service call parameters and exit
}

;Read / Write *CONF. FILE parameters
.Conf0	
{
 	  BCS Conf0Write

;Read *CONF. FILE parameters from RTC register and write to screen
            JSR L9427
            JSR printADecimalPad
            JSR printSpace								;write ' ' to screen
            LDX #userRegDiscNetBootData							;Register &10 (0: File system disc/net flag / 4: Boot / 5-7: Data )
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            LDX #'N'								;'N' - NFS
	  ; SFTODO: If we're desperate for space using LSR A:BCC would save a byte.
            AND #&01								;Isolate file system bit SFTODO: replace with constant if used elsewhere too (prob is?!)
            BEQ L94BA								;NFS?
            LDX #'D'								;'D' - DFS
.L94BA      TXA
            JSR OSWRCH								;Write to screen
            JMP OSNEWL								;New line

;Write *CONF. FILE parameters to RTC register
.Conf0Write
            JSR convertIntegerDefaultDecimalChecked
            STA transientConfigPrefix
            TYA
            PHA
            JSR L93E3
            PLA
            TAY
            JSR findNextCharAfterSpace							;find next character. offset stored in Y
            LDA (transientCmdPtr),Y							;Read File system type
            AND #&DF								;Capitalise
            CMP #'N'								;Is 'N' - NFS
            BEQ L94DD								;CLC then write to register
            CMP #'D'								;Is 'D' - NFS
            BEQ L94DE								;SEC then write to register
            RTS
			
.L94DD      CLC
.L94DE      PHP									;Save File system status bit in Carry flag
            LDX #userRegDiscNetBootData							;Register &10 (0: File system / 4: Boot / 5-7: Data )
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            LSR A									;Rotate old File system status bit out of register
            PLP									;Restore new File system status bit from Carry flag
            ROL A									;Rotate new File system status bit in to register
            JMP writeUserReg							;Write to RTC clock User area. X=Addr, A=Data
}
			
;Read / Write *CONF. <option> <n> parameters
.Conf1
{
	  BCS Conf1Write
            JSR L9427
            JMP L94FC
			
.Conf1Write
            JSR convertIntegerDefaultDecimalChecked
            JMP L93E1 ; SFTODO: move Conf1 block so we can fall through?
}
			
; SFTODO: If we moved this to just before printADecimal we could fall through into it
.printADecimalPad
{
.L94F8      SEC
            JMP printADecimal								;Convert binary number to numeric characters and write characters to screen
}
			
.L94FC      JSR printADecimalPad
            JMP OSNEWL
			
.convertIntegerDefaultDecimalChecked
{
.L9502      JSR convertIntegerDefaultDecimal
            BCS badParameterIndirect
            RTS
			
.badParameterIndirect
            JMP badParameter
}


.L950B		EQUB &04,&02,&01

.Conf3		BCS L9528
            JSR L940A
            LSR A
            BCS L9523
            LSR A
            BCS L951E
            LDA #&00
            JMP L932E
			
.L951E      LDA #&01
            JMP L932E
			
.L9523      LDA #&02
            JMP L932E
			
.L9528      LDX transientConfigPrefix
			LDA L950B,X
            JMP L93E1
			
.Conf6		BCS L9541
            JSR L940A
            LDA ConfParBit+2,Y
            ASL A
            LDA #&00
            ROL A
            EOR transientConfigPrefix
            JMP L932E
			
.L9541      JSR setYToTransientConfIdxTimes3
            LDA ConfParBit+2,Y
            ASL A
            LDA #&00
            ROL A
            EOR transientConfigPrefix
            JMP L93E1
			
.Conf2      BCS L9560
            JSR L940A
            PHA
            JSR L83F2
            PLA
            CLC
            ADC #&01
            JMP L94FC
			
.L9560      JSR convertIntegerDefaultDecimalChecked
            SEC
            SBC #&01
            JMP L93E1
			
.Conf5		BCS L957C
            JSR L940A
            PHA
            JSR L83F2
            PLA
            CMP #&08
            BCC L9579
            ADC #&77
.L9579		JMP L94FC

.L957C      JSR convertIntegerDefaultDecimalChecked
            CMP #&80
            BCC L9585
            SBC #&78
.L9585      JMP L93E1

.Conf4		BCS L95A8
            JSR L940A
            PHA
            JSR L83F2
            PLA
            PHA
            LSR A
            CMP #&04
            BCC L959A
            ORA #&F8
.L959A      JSR printADecimalPad
            LDA #&2C
            JSR OSWRCH
            PLA
            AND #&01
            JMP L94FC
			
.L95A8      JSR convertIntegerDefaultDecimalChecked
            AND #&07
            ASL A
            PHA
            JSR L854D
            JSR convertIntegerDefaultDecimalChecked
            AND #&01
            STA L00AE
            PLA
            ORA L00AE
            JMP L93E1
			
.L95BF      LDA #&00
            ASL L00AE
            ROL A
            ASL L00AE
            ROL A
            RTS

            JSR L95BF								;Missing address label?
            JSR printADecimalPad
            LDA #&2C
            JMP OSWRCH
			
            ASL L00AE								;Missing address label?
            ASL L00AE
            JSR L854D
            JSR convertIntegerDefaultDecimalChecked
            AND #&03
            ORA L00AE
            STA L00AE
            RTS

			
;Autoboot - Service call &03
.service03	LDA KEYVH
            CMP #&FF
            BNE L9605
            LDA #&0D
            STA L00F6
            LDA #&80
            STA L00F7
            LDY L0DDD
            JSR OSRDRM
            CMP #&47
            BNE L9605
            LDA L0DDD
            ORA #&80
            STA L0DDD
.L9605      CLC
            JSR LA7A8
            BIT L03A4
            BPL L9611
            JMP L964C
			
.L9611      JSR PrvEn								;switch in private RAM
            LDX lastBreakType								;get last Break type
            CPX #&01								;power on break?
            BNE L9640								;if not the exit
            CLC
            LDA prv81								;get data from Private RAM
            BEQ L9640								;if 0 then exit
            ADC #&0F
            LDX #&00
.L9625      STA L0B00,X
            INX
            CPX #&11
            BNE L9625
            LDA #&10
            STA L0B0A
            LDX #&01								;Code relocation
.L9634      LDA prv81,X
            STA L0B10,X
            INX
            CPX prv81
            BNE L9634
.L9640      JSR PrvDis								;switch out private RAM
            LDA #&7A
            JSR OSBYTE
            CPX #&FF
            BEQ L9652
.L964C      LDX romselCopy
            DEX
            JMP L968D
			
.L9652      LDA lastBreakType
            BNE L9668
            LDX #&43
            JSR readPrivateRam8300X								;read data from Private RAM &83xx (Addr = X, Data = A)
            PHA
            JSR L966E
            PLA
            AND #&7F
            TAX
            CPX romselCopy
            BCC L968D
.L9668      JSR L966E
            JMP L9680
			
.L966E      LDX #&10								;Register &10 (0: File system / 4: Boot / 5-7: Data )
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            ROR A
            ROR A									;Move File system bit to msb
            AND #&80								;and isolate bit
            TAX
            LDA #&FF								;select read / write start-up options
            LDY #&7F								;retain lower 7 bits
            JSR OSBYTE								;execute read / write start-up options
            RTS
			
.L9680      LDX #&05
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            AND #&0F
            TAX
            CPX romselCopy
            BCC L968D
            DEX
.L968D      JSR L96BC
            LDA lastBreakType
            BNE L969A
            LDA L028C
            BPL L96A7
.L969A      LDX #&05
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            JSR L980B
            JMP L96A7
			
.L96A5      LDA romselCopy
.L96A7      TAX
            LDA L02A1,X
            ROL A
            BPL L96B1
            JMP LDBE6								;OSBYTE 142 - ENTER LANGUAGE ROM AT &8000 (http://mdfs.net/Docs/Comp/BBC/OS1-20/D940)
			
.L96B1      BIT tubePresenceFlag								;check for Tube - &00: not present, &ff: present
            BPL L96A5
            LDA #&00
            CLC
            JMP L0400								;assume there is code within this ROM that is being relocated to &0400???
			
.L96BC      TXA
            PHA
            TSX
            LDA L0104,X
            TAY
            PLA
            TAX
            LDA romselCopy
            PHA
            LDA #&03
            JMP LF16E								;OSBYTE 143 - Pass service commands to sideways ROMs (http://mdfs.net/Docs/Comp/BBC/OS1-20/F135)

;Absolute workspace claim - Service call &01
.service01
{
            LDA #&00
            STA ramselCopy
            STA ramsel								;shadow off
            LDX #&07								;start at address 7
            LDA #&FF								;set data to &FF
.L96D9      JSR writePrivateRam8300X							;write data to Private RAM &83xx (Addr = X, Data = A)
            DEX									;repeat
            BNE L96D9								;until 0.
            LDA romselCopy								;get current ROM number
            AND #&0F								;mask
            JSR writePrivateRam8300X							;write data to Private RAM &83xx (Addr = X, Data = A)
            BIT L03A4								;?
            BPL L96EE
            JMP L9808
			
.L96EE      LDX #userRegPrvPrintBufferStart
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            LDX #prvPrvPrintBufferStart-prv83                                                                   ; SFTODO: not too happy with this format
            JSR writePrivateRam8300X							;write data to Private RAM &83xx (Addr = X, Data = A)
            LDX lastBreakType
            BEQ softBreak
            LDX #userRegOsModeShx								;0-2: OSMODE / 3: SHX
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            PHA
            AND #&07								;mask OSMODE value
            LDX #prvOsMode - prv83								;select OSMODE register
            JSR writePrivateRam8300X								;write data to Private RAM &83xx (Addr = X, Data = A)
            JSR LA4E3								;Assign default pseudo RAM banks to absolute RAM banks
            PLA
            AND #&08
            BEQ L9714
            LDA #&FF
.L9714      LDX #&3D								;select SHX register (&08: On, &FF: Off)
            JSR writePrivateRam8300X								;write data to Private RAM &83xx (Addr = X, Data = A)
.softBreak
.L9719      JSR LBC98
            LDX #&0A								;get TV / MODE parameters
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            PHA									;save value
            ROL A									;move msb to carry
            PHP									;save msb
            ROR A									;move bit from carry back to msb
            LDX #&05								;set counter to 5: move bits 8-5 to 3-0. Pad upper bits with msb
.L9727      PLP									;recover msb
            PHP									;and save again
            ROR A									;store bit to msb
            DEX
            BNE L9727								;loop for 5
            PLP
            TAX									;then save to X
            PLA									;recover parameter &0A value
            AND #&10								;is bit 4 set (TV interlace)?
            BEQ L9736								;no? then jump to set Y=0
            LDA #&01								;else set Y=1
.L9736      TAY									;set Y=0
            LDA #&90								;select *TV X,Y
            JSR OSBYTE								;execute *TV X,Y
            LDA #vduSetMode								;select switch MODE
            JSR OSWRCH								;write switch MODE
            LDX lastBreakType								;Read Hard / Soft Break
            BNE L9758								;Branch on hard break (power on / Ctrl Break)
            LDX #prvOsMode - prv83									;select OSMODE
            JSR readPrivateRam8300X								;read data from Private RAM &83xx (Addr = X, Data = A)
            BEQ L9758								;branch if OSMODE=0
            LDX #prvSFTODOMODE - prv83						;read mode? SFTODO: OK, so probably prvSFTODOMODE is the (configured?) screen mode? That would account for b7 being shadow-ish
            JSR readPrivateRam8300X							;read data from Private RAM &83xx (Addr = X, Data = A)
            JSR OSWRCH								;write mode?
            JMP L9768
			
.L9758      LDX #&0A								;get MODE value - Shadow: bit 3, Mode: bits 0, 1 & 2
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            AND #&0F								;Lower nibble only
            CMP #&08								;Is shadow bit set?
            BCC L9765								;Branch if no shadow (less than &8)
            ADC #&77								;Set MODE to (&80 thru &87): &77 + &1 (Carry) + &8 (shadow enabled) + MODE
.L9765      JSR OSWRCH								;Write MODE
.L9768      JSR L989F
            LDX #&0C								;get keyboard auto-repeat delay (cSecs)
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            TAX
            LDA #&0B								;select keyboard auto-repeat delay
            JSR OSBYTE								;write keyboard auto-repeat delay
            LDX #&0D								;get keyboard auto-repeat rate (cSecs)
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            TAX
            LDA #&0C								;select keyboard auto-repeat rate
            JSR OSBYTE								;write keyboard auto-repeat rate
            LDX #&0E								;get character ignored by printer
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            TAX
            LDA #&06								;select character ignored by printer
            JSR OSBYTE								;write character ignored by printer
            LDX #&0F								;get RS485 baud rate for receiving and transmitting data (bits 2,3,4) & printer destination (bit 5)
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            JSR L980D								;2 x LSR
            PHA
            AND #&07								;get lower 3 bits
            CLC
            ADC #&01								;increment to convert to baud rate
            PHA
            TAX									;baud rate value
            LDA #&07								;select RS485 baud rate for receiving data
            JSR OSBYTE								;write RS485 baud rate for receiving data
            PLA
            TAX									;baud rate value
            LDA #&08								;select RS485 baud rate for transmitting data
            JSR OSBYTE								;write RS485 baud rate for transmitting data
            PLA
            JSR L980C								;3 x LSR
            TAX
            LDA #&05								;select printer destination
            JSR OSBYTE								;write printer destination
            LDX #&0B
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            PHA
            AND #&38
            LDX #&A0								;CAPS Lock Engaged + Shift Enabled?
            CMP #&08								;CAPS Lock Engaged?
            BEQ L97C8
            LDX #&30								;
            CMP #&10								;SHIFT Lock Engaged?
            BEQ L97C8
            LDX #&20
.L97C8      LDY #&00
            LDA #&CA								;select keyboard status byte
            JSR OSBYTE								;write keyboard status byte
            PLA
            AND #&07
            ASL A
            ASL A
            ASL A
            ASL A
            STA L00A8
            LDX #&10								;Register &10 (0: File system / 4: Boot / 5-7: Data )
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            PHA
            LDY #&C8
            LDA lastBreakType
            BEQ L97EE
            PLA
            PHA
            LDY #&C0
            LSR A
            AND #&08
            EOR #&08
.L97EE      ORA L00A8
            ORA #&07
            AND #&3F
            TAX
            LDA #&FF
            JSR OSBYTE
            PLA
            JSR L980C
            AND #&1C
            TAX
            LDY #&E3
            LDA #&9C
            JSR OSBYTE
.L9808      JMP exitSCa								;restore service call parameters and exit
}

.L980B      LSR A
.L980C      LSR A
.L980D      LSR A
            LSR A
            RTS

;Tube system initialisation - Service call &FF
.serviceFF	JSR L984C
            PHA
            BIT prv83+&41
            BMI L9836
            LDA lastBreakType
            BEQ L9831
            BIT L03A4
            BMI L983D
            LDX #&0F
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            AND #&01
            BNE L982E
            LDA #&FF
.L982E      STA prv83+&40
.L9831      BIT prv83+&40
			BPL L983D
.L9836      PLA
            JSR L985D
            JMP exitSCa								;restore service call parameters and exit
			
.L983D      PLA
            JSR L985D
            PLA
            TAY
            PLA
            PLA
            LDA #&FF
            LDX #&00
            JMP LDC16								;Set up Sideways ROM latch and RAM copy (http://mdfs.net/Docs/Comp/BBC/OS1-20/D940)
			
.L984C      LDA ramselCopy
            PHA
            LDA #&00
            STA ramselCopy
            STA ramsel
            JSR PrvEn								;switch in private RAM
            PLA
            RTS
			
.L985D      PHA
            JSR PrvDis								;switch out private RAM
            PLA
            STA ramselCopy
            STA ramsel
            RTS

;Vectors claimed - Service call &0F
.service0F  LDX #&43
            JSR readPrivateRam8300X								;read data from Private RAM &83xx (Addr = X, Data = A)
            AND #&80
            PHA
            LDA #&00
            LDX #&A8
            LDY #&00
            JSR OSARGS
            TSX
            LDY #&00
            CMP #&05
            BEQ L988D
            LDY #&80
            CMP #&04
            BEQ L988D
            LDA L0DBC
            JMP L9896
			
.L988D      LDA L0DBC
            AND #&0F
            TSX
            ORA L0101,X
.L9896      LDX #&43
            JSR writePrivateRam8300X								;write data to Private RAM &83xx (Addr = X, Data = A)
            PLA
            JMP exitSCa								;restore service call parameters and exit
			
.L989F      LDX #prvOsMode - prv83								;select OSMODE
            JSR readPrivateRam8300X								;read data from Private RAM &83xx (Addr = X, Data = A)
            CMP #&00								;If OSMODE=0
            BEQ L991D								;Then no startup message
            LDA #&D7								;Startup message suppression and !BOOT option status
            LDX #&00
            LDY #&FF
            JSR OSBYTE
            TXA
            BPL L991D
            LDA #&D7								;Startup message suppression and !BOOT option status
            LDX #&00
            LDY #&00
            JSR OSBYTE
            LDX #&17								;Start at ROM header offset &17
.L98BF      LDA prv80+&00,X								;Read 'Computech ' from ROM header
            JSR OSWRCH								;Write to screen
            INX									;Next Character
            CPX #&21								;Check for final character
            BNE L98BF								;Loop
            LDX #&09								;Lookup table offset
.L98CC      LDA L991E,X								;Read INTEGRA-B Text from lookup table
            JSR OSWRCH								;Write to screen
            DEX									;Next Character
            BPL L98CC								;Loop
            LDA lastBreakType								;Check Break status. 0=soft, 1=power up, 2=hard
            BEQ L9912								;No Beep and don't write amount of Memory to screen
            LDA #&07								;Beep
            JSR OSWRCH								;Write to screen
            LDX #&7F								;Read 'RAM installed in banks' register
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            STA L00A8
            LDX #&07								;Check all 8 32k banks for RAM
            LDA #&00								;Start with 0k RAM
.L98EA      LSR L00A8								;Check if RAM bank
            BCC L98F0								;If 0 then no RAM, so don't increment RAM count
            ADC #&1F								;Add 32k (&1F + Carry)
.L98F0      DEX									;Check next 32k bank
            BPL L98EA								;Loop until 0
            CMP #&00								;If RAM total = 0k (will occur with either 0 RAM banks or 8 x 32k RAM banks), then
            BEQ L98FE								;Write '256K' to screen
            SEC
            JSR printADecimal								;Convert binary number to numeric characters and write characters to screen
            JMP L990D								;Write 'K' to screen
			
.L98FE      LDA #'2'
            JSR OSWRCH								;Write to screen
            LDA #'5'
            JSR OSWRCH								;Write to screen
            LDA #'6'
            JSR OSWRCH								;Write to screen
.L990D      LDA #'K'
            JSR OSWRCH								;Write to screen
.L9912      JSR OSNEWL								;New Line
            BIT tubePresenceFlag								;check for Tube - &00: not present, &ff: present
            BMI L991D
            JMP OSNEWL								;New Line
			
.L991D      RTS

.L991E		EQUS " B-ARGETNI"							;INTEGRA-B Reversed

.L9928	  JSR PrvEn								;switch in private RAM
            PHP
            SEI
            LDA #&00
            STA oswdbtX
            LDY #&03
.L9933      STY prv82+&52
            LDA prvPseudoBankNumbers,Y
            BMI L994A
            TAX
            JSR testRamUsingVariableMainRamSubroutine
            BNE L994A
            LDA prv83+&2C,X
            BEQ L994D
            CMP #&02
            BEQ L994D
.L994A      CLC
            BCC L994E
.L994D      SEC
.L994E      ROL oswdbtX
            LDY prv82+&52
            DEY
            STY prv82+&52
            BPL L9933
            JMP L9983
			
.L995C      JSR PrvEn								;switch in private RAM
            PHP
            SEI
            LDA #&00
            STA oswdbtX
            LDY #&03
.L9967      STY prv82+&52
            LDA prvPseudoBankNumbers,Y
            BMI L9974
            JSR L9A25
            BPL L9977
.L9974      CLC
            BCC L9978
.L9977      SEC
.L9978      ROL oswdbtX
            LDY prv82+&52
            DEY
            STY prv82+&52
            BPL L9967
.L9983      PLP
            JMP PrvDisexitSc
			
;*SRWIPE Command
.srwipe
{
	  JSR L9B25
            JSR PrvEn								;switch in private RAM
            LDX #&00
.L998F      ROR L00AF
            ROR L00AE
            BCC L9998
            JSR L99A0
.L9998      INX
            CPX #&10
            BNE L998F
            JMP PrvDisexitSc

; SFTODO: This has only one caller, the code immediately above - could it just be inlined?
.L99A0      JSR testRamUsingVariableMainRamSubroutine
            BNE L99BF
            PHA
            LDX #lo(wipeRamTemplate)							;LSB of relocatable Wipe RAM code
            LDY #hi(wipeRamTemplate)							;MSB of relocatable Wipe RAM code
            JSR copyYxToVariableMainRamSubroutine								;relocate &32 bytes of Wipe RAM code from &9E38 to &03A7
            PLA
            JSR variableMainRamSubroutine								;Call relocated Wipe RAM code
            PHA
            JSR L99E5
            PLA
            TAX
            LDA #&00								;
            STA L02A1,X								;clear ROM Type byte
            STA prv83+&2C,X								;clear Private RAM copy of ROM Type byte
.L99BF      RTS
}

; SFTODO: How are these strings accessed? Which label?
		EQUS "RAM","ROM"

; SFTODO: This has only one caller
.writeRomHeaderAndPatchUsingVariableMainRamSubroutine
{
.^L99C6	  PHA
	  LDX #lo(writeRomHeaderTemplate)
	  LDY #hi(writeRomHeaderTemplate)
	  JSR copyYxToVariableMainRamSubroutine								;relocate &32 bytes of code from &9E59 to &03A7
            PLA
            BEQ ram
            ; ROM - so patch variableMainRamSubroutine's ROM header to say "ROM" instead of "RAM"
            LDA #'O'
            STA variableMainRamSubroutine + (writeRomHeaderTemplateDataAO - writeRomHeaderTemplate)
.ram        LDA prvOswordBlockCopy + 1
            JSR checkRamBankAndMakeAbsolute
            STA prvOswordBlockCopy + 1
            STA variableMainRamSubroutine + (writeRomHeaderTemplateSFTODO - writeRomHeaderTemplate)
            JMP variableMainRamSubroutine								;Call relocated code
}
			
.L99E5      LDX #&03
.L99E7      CMP prv83+&0C,X
            BEQ L99F1
            DEX
            BPL L99E7
            SEC
            RTS

.L99F1      LDA #&FF
            STA prv83+&0C,X
.L99F6      LDX #&00
            LDY #&00
.L99FA      LDA prv83+&0C,X
            BMI L9A03
            STA prv83+&0C,Y
            INY
.L9A03      INX
            CPX #&04
            BNE L99FA
            TYA
            TAX
            JMP L9A13
			
.L9A0D      LDA #&FF
            STA prv83+&0C,Y
            INY
.L9A13      CPY #&04
            BNE L9A0D
            RTS
			
.L9A18      PHA
            JSR L99F6
            PLA
            CPX #&04
            BCS L9A24
            STA prv83+&0C,X
.L9A24      RTS

.L9A25      LDX #&03
.L9A27      CMP prv83+&0C,X
            BEQ L9A2F
            DEX
            BPL L9A27
.L9A2F      RTS

;*SRSET Command
{
.^srset     LDA (L00A8),Y
            CMP #&3F
            BEQ L9A79
            JSR parseRomBankList
            JSR PrvEn								;switch in private RAM
            LDX #&00
            LDY #&00
.L9A40      ROR L00AF
            ROR L00AE
            BCC L9A67
            TYA
            PHA
            JSR testRamUsingVariableMainRamSubroutine
            BNE L9A59
            LDA prv83+&2C,X
            BEQ L9A56
            CMP #&02
            BNE L9A59
.L9A56      CLC
            BCC L9A5A
.L9A59      SEC
.L9A5A      PLA
            TAY
            BCS L9A67
            TXA
            STA prvPseudoBankNumbers,Y
            INY
            CPY #&04
            BCS L9A76
.L9A67      INX
            CPX #&10
            BNE L9A40
            LDA #&FF
.L9A6E      STA prvPseudoBankNumbers,Y
            INY
            CPY #&04
            BCC L9A6E
.L9A76      JMP PrvDisexitSc

.L9A79      CLC
            JSR PrvEn								;switch in private RAM
            LDY #&00
.L9A7F      CLC
            TYA
            ADC #'W'								;Start at 'W'
            JSR OSWRCH
            LDA #'='
            JSR OSWRCH								;Write to screen
            LDA prvPseudoBankNumbers,Y								;read absolute bank assigned to psuedo bank
            BPL L9A98								;check if valid bank has been assigned
            LDA #'?'
            JSR OSWRCH								;Write to screen
            JMP L9A9C								;Next
			
.L9A98      SEC
            JSR printADecimal								;Convert binary number to numeric characters and write characters to screen
.L9A9C      CPY #&03								;Check for 4th bank
            BEQ L9AAB								;Yes? Then end
            LDA #','
            JSR OSWRCH								;Write to screen
            JSR printSpace								;write ' ' to screen
            INY										;Next
            BNE L9A7F								;Loop for 'X', 'Y' & 'Z'
.L9AAB      JSR OSNEWL								;New Line
            JMP PrvDisexitSc
}

{
;*SRROM Command
.^srrom	  SEC
            BCS L9AB5

;*SRDATA Command
.^srdata
            CLC
.L9AB5      PHP
            JSR L9B25
            JSR PrvEn								;switch in private RAM
            LDX #&00
.L9ABE      ROR L00AF
            ROR L00AE
            BCC L9AC9
            PLP
            PHP
            JSR L9AD1
.L9AC9      INX
            CPX #&10
            BNE L9ABE
            JMP L9983
			
.L9AD1      STX prvOswordBlockCopy + 1
            PHP
            LDA #&00
            ROR A
            STA L00AD
            JSR testRamUsingVariableMainRamSubroutine
            BNE L9B0D
            LDA prv83+&2C,X
            BEQ L9AE8
            CMP #&02
            BNE L9B0D
.L9AE8      LDA prvOswordBlockCopy + 1
            JSR L99E5
            PLP
            BCS L9AF9
            LDA prvOswordBlockCopy + 1
            JSR L9A18
            BCS L9B12
.L9AF9      LDA L00AD
            JSR writeRomHeaderAndPatchUsingVariableMainRamSubroutine
            LDX prvOswordBlockCopy + 1
            LDA #&02
            STA prv83+&2C,X
            STA L02A1,X
.L9B09      LDX prvOswordBlockCopy + 1
.L9B0C      RTS

.L9B0D      PLP
            SEC
            CLV
            BCS L9B09
.L9B12      SEC
            BIT L9B0C
            BCS L9B09
.^checkRamBankAndMakeAbsolute
.L9B18     AND #&7F						;drop the highest bit
            CMP #&10						;check if RAM bank is absolute or pseudo address 
            BCC L9B24
            TAX
            ; SFTODO: Any danger this is ever going to have X>3 and access an arbitrary byte?
            LDA prvPseudoBankNumbers,X						;lookup table to convert pseudo RAM W, X, Y, Z into absolute address???
            BMI L9B2B						;check for Bad ID
.L9B24      RTS
}

.L9B25      JSR parseRomBankList
            BCS L9B2B
            RTS
			
.L9B2B      JMP badId						;Error Bad ID

.L9B2E      LDX #&00
.L9B30      STY L00AC
            STA L00AD
            SEC
            LDA L00AC
            SBC #&F0
            TAY
            LDA L00AD
            SBC #&3F
            BCC L9B43
            INX
            BNE L9B30
.L9B43      CLC
            LDA L00AC
            ADC #&10
            TAY
            LDA L00AD
            ADC #&00
            ORA #&80
            RTS

; SFTODO: This comment is a WIP
; OSWORD &42 and &43 do similar jobs but have different parameter blocks. In order to share code between them more easily,
; we copy user-supplied parameter blocks into private RAM at prvOswordBlockCopy and swizzle them into an internal format (adjustPrvOsword42Block/adjustPrvOsword43Block SFTODO: rename those to use the word 'swizzle' instead of adjust?)
; which makes the similarities more exploitable.
; XY?0      function
; XY?1      absolute ROM number
; XY+2..5   OSWORD &42: main memory address (may be in host or parasite)
;           OSWORD &43: buffer address (in host, high word always &FFFF)
; XY+6..7   OSWORD &42: data length
;           OSWORD &43: buffer length, 0 => no buffer, >=&8000 => use PAGE-HIMEM as buffer (ignore user-supplied buffer address)
; XY+8..9   sideways RAM start address
; XY+10..11 OSWORD &43 only: data length (ignored on load, buggy on save; see comment below)
; XY+12..13 OSWORD &43 only: filename in I/O processor
;
; SFTODO:
; For OSWORD &43, XY+10..11 *should* be the data length, but a bug in adjustPrvOsword43Block means
; that will actually be set to the user-supplied buffer length (before any adjustment is made
; if PAGE-HIMEM is used as a buffer). This only affects direct OSWORD &43 calls; *SRSAVE sets up
; the OSWORD block directly at prvOswordBlockCopy in the internal format and isn't affected by this bug.


			
;this routine moves the contents of the osword43 parameter block up by one byte
;and inserts the absolute ROM number into offset 1, so block becomes:
; XY?0     =function as for OSWORD &42 (66)
; XY?1     =absolute ROM number as for OSWORD &42 (66)
; XY+2..3  =buffer address
; XY+4..5  ="high word" of buffer address, always &FFFF (i.e. I/O processor) - this is set up by adjustOsword43LengthAndBuffer, for consistency with our internal OSWORD &42 block
; XY+6..7  =buffer length. If the buffer address is zero, a
;  default buffer is used in private workspace. If the
;  buffer length is larger than &7FFF, then language
;  workspace from PAGE to HIMEM is used.
; XY+8..9  =sideways start address
; XY+10..11=data length - ignored on LOAD SFTODO: except as Ken's comments below indicate, it will actually be another copy of buffer length
; XY+12..13=>filename in I/O processor
; SFTODO: Is it possible we never use +10/11 even on SAVE? But we must, otherwise we wouldn't know how much to save.
; SFTODO: Is it possible XY+10..11 *is* deliberately being set to be a copy of buffer length, because we adjust one or other copy, and it works out correctly in the end? I am dubious but maybe... The way the code's written below is a very odd way of achieving this if it's deliberate.
; SFTODO: Note that adjustOsword43LengthAndBuffer overwrites XY+10..11 with the actual file length obtained via OSFILE if this is a load operation; I haven't finished tracing through the code yet, but I suspect this masks the "copy of buffer length" bug on loads. I think saves are probably buggy, but how often is *SRSAVE actually used, assuming it calls OSWORD &43 internally? And it may be that (I haven't looked at the code yet) that *SRSAVE *does* work if you're saving an entire bank or something like that.
; SFTODO: The way this block is set up by *SRSAVE and *SRLOAD is almost certainly the *right* way, so go through that code and then update all comments to reflect that and just document in the relevant places that this routine is buggy and sets it up wrong and what the consequences are

.adjustPrvOsword43Block
; SFTODO: Could this be rewritten more compactly as a loop?
; SFTODO: This only has one caller
{
.L9B50      LDA prvOswordBlockCopy + 1
            STA prvOswordBlockCopy + 12
            LDA prvOswordBlockCopy + 2
            STA prvOswordBlockCopy + 13
            LDA prvOswordBlockCopy + 3
            JSR checkRamBankAndMakeAbsoluteAndUpdatePrvOswordBlockCopy                    ;convert pseudo RAM bank to absolute RAM bank & save to private address &21
            LDA prvOswordBlockCopy + 8
            STA prvOswordBlockCopy + 2
            LDA prvOswordBlockCopy + 9
            STA prvOswordBlockCopy + 3
            LDA prvOswordBlockCopy + 4
            STA prvOswordBlockCopy + 8
            LDA prvOswordBlockCopy + 5
            STA prvOswordBlockCopy + 9
            LDA prvOswordBlockCopy + 10
            STA prvOswordBlockCopy + 6
            LDA prvOswordBlockCopy + 11
            STA prvOswordBlockCopy + 7
            LDA prvOswordBlockCopy + 6							;<----This won't work, because we've already overwritten &26 with &2A!!!
            STA prvOswordBlockCopy + 10							;<----This won't work, because we've already overwritten &26 with &2A!!!
            LDA prvOswordBlockCopy + 7							;<----This won't work, because we've already overwritten &27 with &2B!!!
            STA prvOswordBlockCopy + 11							;<----This won't work, because we've already overwritten &27 with &2B!!!
            RTS
}
			
;this routine moves the contents of the osword42 parameter block up by one byte
;and inserts the absolute ROM number into offset 1, so block becomes:
; XY?0   =function
; XY?1   =absolute ROM number
; XY!2   =main memory address
; XY+6..7=data length
; XY+8..9=sideways address
;The functions are:
;&00 - Read from absolute address
;&40 - Read from pseudo-address
;&80 - Write to absolute address
;&C0 - Write to pseudo-address

; SFTODO: Could this be rewritten more compactly as a loop?
; SFTODO: This has only one caller
.adjustPrvOsword42Block
{
.L9B93      LDA prvOswordBlockCopy + 7						;ROM number
            PHA
            LDA prvOswordBlockCopy + 6
            STA prvOswordBlockCopy + 7
            LDA prvOswordBlockCopy + 5
            STA prvOswordBlockCopy + 6
            LDA prvOswordBlockCopy + 4
            STA prvOswordBlockCopy + 5
            LDA prvOswordBlockCopy + 3
            STA prvOswordBlockCopy + 4
            LDA prvOswordBlockCopy + 2
            STA prvOswordBlockCopy + 3
            LDA prvOswordBlockCopy + 1
            STA prvOswordBlockCopy + 2
            PLA
.^checkRamBankAndMakeAbsoluteAndUpdatePrvOswordBlockCopy ; SFTODO: catchy!
.L9BBC     JSR checkRamBankAndMakeAbsolute						;convert pseudo RAM bank to absolute RAM bank
            STA prvOswordBlockCopy + 1						;and save to private address &8221
            RTS
}

; SFTODO: Returns with C clear in "simple" case, C set in the "mystery" case
.parseBankNumberIfPresent ; SFTODO: probably imperfect name, will do until the mystery code in middle is cleared up
{
.L9BC3      JSR parseBankNumber
            BCC parsedOk
            LDA #&FF ; SFTODO: What happens if we have the ROM number set to &FF later on?
.parsedOk   STA prvOswordBlockCopy + 1						;absolute ROM number
            BCC parsedOk2
	  ; SFTODO: What do these addresses hold?
            LDA prv83+&0C
            AND prv83+&0D
            AND prv83+&0E
            AND prv83+&0F
            BMI badIdIndirect
            LDA prvOswordBlockCopy						;function
            ORA #&40							;set pseudo addressing mode
            STA prvOswordBlockCopy						;function
.parsedOk2  RTS

.badIdIndirect
            JMP badId
}

; SFTODO: This has only a single caller
.parseSrsaveLoadFlags
{
.L9BE9      LDA #&00
            STA prvOswordBlockCopy + 6							;low byte of buffer length
            STA prvOswordBlockCopy + 7							;high byte of buffer length
.L9BF1      JSR findNextCharAfterSpace							;find next character. offset stored in Y
            LDA (transientCmdPtr),Y
            CMP #vduCr
            BEQ rts  								;Yes? Then jump to end
            AND #&DF								;Capitalise
            CMP #'Q'								;'Q'
            BNE L9C07								;No? Goto next check
            LDA #&80								;set bit 7
            STA prvOswordBlockCopy + 7							;high byte of buffer length
            BNE L9C1E								;Increment and loop
.L9C07      CMP #'I'								;'I'
            BNE L9C12								;No? Goto next check
            LDA prvOswordBlockCopy							;function
            ORA #&01								;set bit 0 SFTODO: aha, so this and code below is where the mysterious undocumented function bits are set - update other comments, perhaps used named constants for this
            BNE L9C1B								;write function, increment and loop
.L9C12      CMP #'P'								;'P' ; SFTODO: what does this do? it's not in *HELP output I think
            BNE L9C1E								;Increment and loop
            LDA prvOswordBlockCopy							;function
            ORA #&02								;set bit 1
.L9C1B      STA prvOswordBlockCopy							;function
.L9C1E      INY									;Next Character
            BNE L9BF1								;Loop
.rts        RTS									;End
}

; SFTODO: This has only one caller
.getSrsaveLoadFilename
{
.L9C22      CLC
            TYA
            ADC transientCmdPtr
            STA prvOswordBlockCopy + 12							;low byte of filename in I/O processor
            LDA transientCmdPtr + 1
            ADC #&00
            STA prvOswordBlockCopy + 13							;high byte of filename in I/O processor
.L9C30      LDA (transientCmdPtr),Y
            CMP #' '
            BEQ L9C3D
            CMP #vduCr
            BEQ syntaxErrorIndirect
            INY
            BNE L9C30
.L9C3D      INY
            RTS
}
			
.syntaxErrorIndirect
	  JMP syntaxError

.L9C42      JSR convertIntegerDefaultHex
            BCS syntaxErrorIndirect
            LDA L00B0
            STA prvOswordBlockCopy + 8
            LDA L00B1
            STA prvOswordBlockCopy + 9
            RTS
			
.L9C52      JSR findNextCharAfterSpace								;find next character. offset stored in Y
            LDA (transientCmdPtr),Y
            CMP #'@'
            BNE parseOsword4243BufferAddress
            INY
            TYA
            PHA
            LDA tubePresenceFlag
            BPL L9C67
            LDA #&08
            BNE L9C71
.L9C67      LDA #&B4								;select read/write OSHWM
            LDX #&00
            LDY #&FF
            JSR OSBYTE								;execute read/write OSHWM
            TYA
.L9C71:     STA prvOswordBlockCopy + 3
            LDA #&00
            STA prvOswordBlockCopy + 2
            STA prvOswordBlockCopy + 4
            STA prvOswordBlockCopy + 5
            PLA
            TAY
            RTS
			
; Parse a 32-bit hex-default value from the command line and store it in the "buffer address" part of prvOswordBlockCopy. (Some callers will move it from there to where they really want it afterwards.)
.parseOsword4243BufferAddress
{
.L9C82      JSR convertIntegerDefaultHex
            BCS syntaxErrorIndirect
            LDA L00B0
            STA prvOswordBlockCopy + 2
            LDA L00B1
            STA prvOswordBlockCopy + 3
            LDA L00B2
            STA prvOswordBlockCopy + 4
            LDA L00B3
            STA prvOswordBlockCopy + 5
            RTS
}
			
.parseOsword4243Length
{
.L9C9C      JSR findNextCharAfterSpace								;find next character. offset stored in Y
            LDA (transientCmdPtr),Y
            CMP #'+'
            PHP
            BNE L9CA7
            INY
.L9CA7      JSR convertIntegerDefaultHex
            BCS syntaxErrorIndirect
            PLP
            BEQ L9CC7
	  ; SFTODO: I think the next three lines give the Integra-B style "exclusive" end address on *SRSAVE - do they have a similarly "incompatible-with-Master" effect on other commands calling this code, or is this adjustment required to be compatible on those other cases?
            INC L00B0
            BNE L9CB5
            INC L00B1
.L9CB5      SEC
            LDA L00B0
            SBC prvOswordBlockCopy + 2
            STA prvOswordBlockCopy + 6
            LDA L00B1
            SBC prvOswordBlockCopy + 3
            STA prvOswordBlockCopy + 7
            RTS
}
			
.L9CC7      LDA L00B0
            STA prvOswordBlockCopy + 6
            LDA L00B1
            STA prvOswordBlockCopy + 7
            RTS
			
;*SRREAD Command
.srread	  JSR PrvEn								;switch in private RAM
            LDA #&00
            JMP L9CDF
			
;*SRWRITE Command
.srwrite	  JSR PrvEn								;switch in private RAM
            LDA #&80
.L9CDF      STA prvOswordBlockCopy
            LDA #&00
            STA L02EE
            JSR L9C52
            JSR parseOsword4243Length
            JSR L9C42
            JSR parseBankNumberIfPresent
            JMP LA0A6

; SFTODO: slightly poor name based on quick scan of code below, I don't know
; exactly how much data this is transferring and be good to document where
; from/to
; SFTODO: This has only one caller
.transferBlock
{
.L9CF6      LDA L00AD
            PHA
            LDA L00AC
            PHA
.L9CFC      LDA L00AD
            BEQ L9D0D
            LDY #&FF
            JSR variableMainRamSubroutine								;Call relocated code
            INC L00A9
            INC L00AB
            DEC L00AD
            BNE L9CFC
.L9D0D      LDY L00AC
            BEQ L9D15
            DEY
            JSR variableMainRamSubroutine								;Call relocated code
.L9D15      PLA
            STA L00AC
            PLA
            STA L00AD
            CLC
            LDA L00A8
            ADC L00AC
            STA L00A8
            BCC L9D26
            INC L00A9
.L9D26      CLC
            LDA L00AA
            ADC L00AC
            STA L00AA
            BCC L9D31
            INC L00AB
.L9D31      RTS
}

; SFTODO: I am thinking if the &Ax addresses are used consistently-ish
; throughout the transfer code, giving them meaningful names would probably
; help. Should probably start with "transfer" as I'm sure the same addresses are
; used for different things in other parts of the code.
; SFTODO: This has only one caller
; SFTODO: I think this has something to do with stopping at the end of the current SWR bank even if we request more data transfer (probably so we can adjust the absolute bank when doing a pseudo-addressing transfer before continuning on next pass round the loop), and we return with "bytes to do in this chunk" (16-bit) at L00AC and transientOs4243BytesToTransfer adjusted to indicate how much data remains to transfer this this chunk. *This code* makes me think the bug in the osword 43 adjustment is that prvOswordBlockCopy+6/7 should be the data length; see getBufferAddressAndLengthFromPrvOswordBlockCopy, which is used for both OSWORD &42 and &43 and where using these conventions would be a lot more consistent. (I *think* I/we had been thinking the bug was that ...blockCopy+10/11 "should" be the data length, but I am now thinking they are meant to be the buffer length. Needs a fresh look with this new perspective.)
.adjustTransferParameters ; SFTODO: temporary name, rename once I understand better
{
; SFTODO: (AD AC) = &C000 - (A9 A8), then L9D42
.L9D32      SEC
            LDA #&00
            SBC transientOs4243SwrAddr
            STA L00AC
            LDA #&C0
            SBC transientOs4243SwrAddr + 1
            STA L00AD
            JMP L9D42 ; SFTODO: This is redundant and could be replaced by FALLTHROUGH_TO L9D42

; SFTODO: calculate n=(AF AE) - (AD AC), if n<0 go to L9D53 else (AE AF)=n:RTS
.L9D42      SEC
            LDA transientOs4243BytesToTransfer
            SBC L00AC
            TAY
            LDA transientOs4243BytesToTransfer + 1
            SBC L00AD
            BCC L9D53
            STA transientOs4243BytesToTransfer + 1
            STY transientOs4243BytesToTransfer
            RTS

; SFTODO: (AD AC) = (AF AE), (AF AE) = 0, RTS
.L9D53      LDA transientOs4243BytesToTransfer
            STA L00AC
            LDA transientOs4243BytesToTransfer + 1
            STA L00AD
            LDA #&00
            STA transientOs4243BytesToTransfer
            STA transientOs4243BytesToTransfer + 1
            RTS
}

.SFTODOsetVandCBasedOnSomethingAndMaybeSwizzleStuff
; SFTODO: This has only one caller
{
.^L9D62     BIT prvOswordBlockCopy                                                                  ;get function
            BVC sevSecRts                                                                            ;branch if we have an absolute address
            ; We're dealing with a pseudo-address.
            BIT L00A9
            BVC clcRts
            LDA #&10
            STA L00A8
            LDA #&80
            STA L00A9
            ; SFTODO: is this an "absolute" ROM number after all? I think
            ; blockCopy+1 is the bank number 0-3 for the 64K pseudo address
            ; space in this code path (which, if correct, means comment at
            ; adjustPrvOsword42Block needs tweaking and so maybe do other
            ; comments on Copy+1 like those immediately below)
            INC prvOswordBlockCopy + 1                                                              ;increment absolute ROM number
            LDA prvOswordBlockCopy + 1                                                              ;get absolute ROM number
            CMP #&04
            BCS sevSecRts
            TAX
            LDA prv83+&0C,X
            BMI clvSecRts
            TAX
.clcRts
.L9D84      CLC
            RTS

.sevSecRts
.L9D86      BIT rts ; set V
            SEC
.rts
.L9D8A      RTS

.clvSecRts
.L9D8B      CLV
            SEC
            RTS
}

; SFTODO: Not the most descriptive name but will do for now - I am looking at
; this in context of OSWORD &42, but I think it's used in quite a few places so
; can name it properly once more code labelled up
.doTransfer
{
.L9D8E      JSR adjustTransferParameters
            LDX prvOswordBlockCopy + 1	; SFTODO: We seem to be treating this as a ROM bank of some kind, but prvOswordBlockCopy+1 will be the leftover low byte of the filename in the OSWORD &43 case, won't it?! In any case, it's not clear to me we use this outside the few instructions before absoluteAddress, so why not just do it *after* the BVC? Negligible performance gain but I think it's clearer (if it's really *not* used on the other code path)
            BIT prvOswordBlockCopy                                                                  ; get function
            BVC absoluteAddress
            ; We're dealing with a pseudo-address.
            ; SFTODO: What do next four lines do?
            LDA prv83+&0C,X
            CLV
            BMI L9DAE
            TAX
.absoluteAddress
.L9DA0      JSR transferBlock
            LDA transientOs4243BytesToTransfer
            ORA transientOs4243BytesToTransfer + 1
            BEQ rts
            JSR SFTODOsetVandCBasedOnSomethingAndMaybeSwizzleStuff
            BCC doTransfer
.L9DAE      LDA L02EE
            BEQ errorBadAddress ; SFTODO: Why would we generate a "Bad address" error if the file handle is 0?!
            PHP
            ; SFTODO: I am reading this code in the context of OSWORD &42, so
            ; closing a file handle seems really weird; am I missing something?
            ; To be fair, provided L02EE is 0 we don't even try to close it, and
            ; presumably this is used on some other code paths too. That's probably
	  ; true, as this is used in OSWORD &43 too and L02EE probably is a file
	  ; handle.
            JSR closeHandleL02EE
            PLP
.errorBadAddress
.L9DB8      BVC errorNotAllocated
            JSR raiseError								;Goto error handling, where calling address is pulled from stack
	  EQUB &80
	  EQUS "Bad address", &00

.errorNotAllocated
.L9DCA      JSR raiseError								;Goto error handling, where calling address is pulled from stack
	  EQUB &80
	  EQUS "Not allocated", &00

.rts        RTS
}

.getAddressesAndLengthFromPrvOswordBlockCopy
; SFTODO: The comments on what's in the OSWORD block are based on OSWORD &42
; after adjustPrvOsword42Block has been called; I see this is used with OSWORD
; &43 too, which has a very different looking parameter block, but I'm guessing
; there's a swizzling routine analogous I haven't labelled yet
; (adjustPrvOsword43Block-to-be, presumably)
{
.L9DDD      LDY prvOswordBlockCopy + 8 ; get low byte of sideways address
            LDA prvOswordBlockCopy + 9 ; get high byte of sideways address
            BIT prvOswordBlockCopy ; test function
            BVC absoluteAddress
            JSR L9B2E ; SFTODO: presumably swizzles pseudo address to absolute address, not checked yet
            STX prvOswordBlockCopy + 1
.absoluteAddress
            STY transientOs4243SwrAddr
            STA transientOs4243SwrAddr + 1
.^getBufferAddressAndLengthFromPrvOswordBlockCopy
.L9DF2      LDA prvOswordBlockCopy + 2 ; get low byte of main memory address (OSWORD &42) or buffer address (OSWORD &43)
            STA transientOs4243MainAddr
            LDA prvOswordBlockCopy + 3 ; get high byte of main memory address (OSWORD &42) or buffer address (OSWORD &43)
            STA transientOs4243MainAddr + 1
            LDA prvOswordBlockCopy + 6 ; get low byte of data length (OSWORD &42) or buffer length (OSWORD &43)
            STA transientOs4243BytesToTransfer
            LDA prvOswordBlockCopy + 7 ; get high byte of data length (OSWORD &42) or buffer length (OSWORD &43)
            STA transientOs4243BytesToTransfer + 1
            CLC ; SFTODO: callers seem to test carry, but it's not clear it can ever be set - if so, we can delete those checks and associated code...
            RTS

; SFTODO: Are next two instructions unreachable?
            SEC										;address label missing?
            RTS
}

;test slots for RAM by writing to &8008 - ROM header
;On entry A=ROM bank to test
;On exit A=X=ROM bank that has been tested. Z contains test result.
;this code is relocated to and executed at &03A7
.testRamTemplate
{
.L9E0A	  LDX romselCopy										;Read current ROM number from &F4 and store in X
            STA romselCopy										;Write new ROM number from A to &F4
            STA romsel									;Write new ROM number from A to &FE30
            LDA romBinaryVersion									;Read contents of &8008
            EOR #&FF									;and XOR with &FF 
            STA romBinaryVersion									;Write XORd data back to &8008
            JSR variableMainRamSubroutine+L9E37-L9E0A								;Delay 1 before read back
            JSR variableMainRamSubroutine+L9E37-L9E0A								;Delay 2 before read back
            JSR variableMainRamSubroutine+L9E37-L9E0A								;Delay 3 before read back
            JSR variableMainRamSubroutine+L9E37-L9E0A								;Delay 4 before read back
            CMP romBinaryVersion									;Does contents of &8008 match what has been written?
            PHP										;Save test
            EOR #&FF									;XOR again with &FF to restore original data
            STA romBinaryVersion									;store original data back to &8008
            LDA romselCopy										;read current ROM number from &F4 and store in A
            STX romselCopy										;restore original ROM number to &F4
            STX romsel									;restore original ROM number to &FE30
            TAX										;copy original ROM number from A to X
            PLP										;recover test
.L9E37	  RTS
            ASSERT P% - testRamTemplate <= variableMainRamSubroutineMaxSize
}

;Wipe RAM at bank A
;this code is relocated to and executed at &03A7
.wipeRamTemplate
{
.L9E38	  LDX romselCopy
            STA romselCopy
            STA romsel
            LDA #&00
.L9E41      STA prv80+&00 ; SFTODO: Change to &8000? I think this is wiping arbitrary banks, not particular private RAM.
            INC variableMainRamSubroutine+L9E41-L9E38+1								;Self modifying code - increment LSB of STA in line above
            BNE L9E41									;Test for overflow
            INC variableMainRamSubroutine+L9E41-L9E38+2								;Increment MSB of STA in line above
            BIT variableMainRamSubroutine+L9E41-L9E38+2								;test MSB bit 6 (have we reached &4000?)
            BVC L9E41									;No? Then loop
            LDA romselCopy
            STX romselCopy
            STX romsel
            RTS
            ASSERT P% - wipeRamTemplate <= variableMainRamSubroutineMaxSize
}

;write ROM header to RAM at bank A
;this code is relocated to and executed at &03A7
.writeRomHeaderTemplate
{
.L9E59	  LDX romselCopy
            STA romselCopy
            STA romsel
            LDY #&0F
.L9E62      LDA variableMainRamSubroutine + srData - writeRomHeaderTemplate,Y
            STA &8000,Y    
            DEY
            BPL L9E62
            LDA romselCopy
            STX romselCopy
            STX romsel
            RTS

;ROM Header
.srData	  EQUB &60
.^writeRomHeaderTemplateSFTODO ; SFTODO: Why do we modify this byte of the header?
            EQUB     &00,&00
	  EQUB &60,&00,&00
	  EQUB &02
	  EQUB &0C
	  EQUB &FF
	  EQUS "R"
.^writeRomHeaderTemplateDataAO
            EQUS "AM", &00
	  EQUS "(C)"
            ASSERT P% - writeRomHeaderTemplate <= variableMainRamSubroutineMaxSize
}

;save ROM / RAM at bank X to file system
;this code is relocated to and executed at &03A7
.saveSwrTemplate
{
.L9E83	  TXA
	  LDX romselCopy
            STA romselCopy
            STA romsel
            INY
            ; SFTODO: We could STY this directly to immediate operand of CPY #n, saving a byte.
            STY variableMainRamSubroutine + (saveSwrTemplateBytesToRead - saveSwrTemplate)
            LDY #&00
            ; SFTODO: It would be shorter by one byte to just STY to overwrite the operand of LDY #n after JSR OSBPUT.
.L9E91      STY variableMainRamSubroutine + (saveSwrTemplateSavedY - saveSwrTemplate)
            LDA (L00A8),Y
            LDY L02EE
            JSR OSBPUT
            LDY variableMainRamSubroutine + (saveSwrTemplateSavedY - saveSwrTemplate)
            INY
            CPY variableMainRamSubroutine + (saveSwrTemplateBytesToRead - saveSwrTemplate)
            BNE L9E91
            LDA romselCopy
            STX romselCopy
            STX romsel
            TAX
            RTS
.saveSwrTemplateBytesToRead
saveSwrTemplateSavedY = saveSwrTemplateBytesToRead + 1
            ; There are two bytes of space used here when this copied into RAM, but
            ; they're not present in the ROM, hence P% + 2 in the next line.
            ASSERT (P% + 2) - saveSwrTemplate <= variableMainRamSubroutineMaxSize
}

;load ROM / RAM at bank X from file system
;this code is relocated to and executed at &03A7
.loadSwrTemplate
{
.L9EAE	  TXA
            LDX romselCopy
            STA romselCopy
            STA romsel
            INY
            ; SFTODO: We could STY this directly to immediate operand of CPY #n, saving a byte.
            STY variableMainRamSubroutine + (loadSwrTemplateBytesToRead - loadSwrTemplate)
            LDY #&00
            ; SFTODO: It would be shorter by one byte to just STY to overwrite the operand of LDY #n after JSR OSBGET.
.L9EBC      STY variableMainRamSubroutine + (loadSwrTemplateSavedY - loadSwrTemplate)
            LDY L02EE
            JSR OSBGET
            LDY variableMainRamSubroutine + (loadSwrTemplateSavedY - loadSwrTemplate)
            STA (transientOs4243SwrAddr),Y ; SFTODO: I think this is used by OSWORD &43, if so rename transientOs4243SwrAddr TO INDICATE APPLIES TO BOTH (tho that's only a temp name)
            INY
            CPY variableMainRamSubroutine + (loadSwrTemplateBytesToRead - loadSwrTemplate)
            BNE L9EBC
            LDA romselCopy
            STX romselCopy
            STX romsel
            TAX
            RTS
.loadSwrTemplateBytesToRead
loadSwrTemplateSavedY = loadSwrTemplateBytesToRead + 1
            ; There are two bytes of space used here when this copied into RAM, but
            ; they're not present in the ROM, hence P% + 2 in the next line.
            ASSERT (P% + 2) - loadSwrTemplate <= variableMainRamSubroutineMaxSize
}

;Function TBC
;this code is relocated to and executed at &03A7
.mainRamTransferTemplate
{
.L9ED9	  TXA									;&03A7
            LDX romselCopy									;&03A8
            STA romselCopy									;&03AA
            STA romsel								;&03AC
            CPY #&00								;&03AF
            BEQ L9EEC								;&03B1
.^mainRamTransferTemplateLdaStaPair1
.L9EE5      LDA (transientOs4243SwrAddr),Y								;&03B3 - Note this is changed to &AA by code at &9FA4
            STA (transientOs4243MainAddr),Y								;&03B5 - Note this is changed to &A8 by code at &9FA4
            DEY									;&03B7
            BNE L9EE5								;&03B8

.^mainRamTransferTemplateLdaStaPair2
.L9EEC      LDA (transientOs4243SwrAddr),Y								;&03BA - Note this is changed to &AA by code at &9FA4
            STA (transientOs4243MainAddr),Y								;&03BC - Note this is changed to &A8 by code at &9FA4
            LDA romselCopy									;&03BE
            STX romselCopy									;&03C0
            STX romsel								;&03C2
            TAX									;&03C5
            RTS									;&03C6
            ASSERT P% - mainRamTransferTemplate <= variableMainRamSubroutineMaxSize
}

; Transfer Y+1 bytes between host (sideways RAM, starting at address in L00A8)
; and parasite (starting at address set up when initiating tube transfer before
; this code was called). The code is patched when it's transferred into RAM to
; do the transfer in the appropriate direction.
; SFTODO: If Y=255 on entry I think we will transfer 256 bytes, but double-check that later.
.tubeTransferTemplate
{
.L9EF9	  TXA
            LDX romselCopy
            STA romselCopy
            STA romsel
            INY
            STY variableMainRamSubroutine + (tubeTransferTemplateTransferSize - tubeTransferTemplate)
            LDY #&00
.^tubeTransferTemplateReadSwr
.L9F07      BIT SHEILA+&E4
            BVC L9F07
            LDA (transientOs4243SwrAddr),Y
            STA SHEILA+&E5
.^tubeTransferTemplateReadSwrEnd
            JSR variableMainRamSubroutine + (tubeTransferTemplateRts - tubeTransferTemplate)
            JSR variableMainRamSubroutine + (tubeTransferTemplateRts - tubeTransferTemplate)
            JSR variableMainRamSubroutine + (tubeTransferTemplateRts - tubeTransferTemplate)
            INY
            CPY variableMainRamSubroutine + (tubeTransferTemplateTransferSize - tubeTransferTemplate)
            BNE L9F07
            LDA romselCopy
            STX romselCopy
            STX romsel
            TAX
.tubeTransferTemplateRts
            RTS
.tubeTransferTemplateTransferSize
            ; There is a byte of space used here when this copied into RAM, but
            ; it's not present in the ROM, hence P% + 1 in the next line.
            ASSERT (P% + 1) - tubeTransferTemplate <= variableMainRamSubroutineMaxSize


;This code is relocated to &03B5. Refer to code at &9F98
; SFTODO: The first three bytes of patched code are the same either way, unless
; there's another hidden patch we could save three bytes by not patching those.
.^tubeTransferTemplateWriteSwr
.L9F29      BIT SHEILA+&E4
            BPL L9F29
            LDA SHEILA+&E5
            STA (transientOs4243SwrAddr),Y
            ASSERT P% - tubeTransferTemplateWriteSwr == tubeTransferTemplateReadSwrEnd - tubeTransferTemplateReadSwr
}

;relocate &32 bytes of code from address X (LSB) & Y (MSB) to &03A7
;This code is called by several routines and relocates the following code:
;L9E0A - Test if RAM at bank specified by A is writable
;L9E38 - Wipe RAM at SWRAM bank specified by A
;L9E59 - Write ROM Header info to SWRAM bank specified by A
;L9E83 - Save RAM at SWRAM bank specified by A to file system
;L9EAE - Load RAM to SWRAM bank specified by A from file system
;L9ED9 - 
;L9EF9 -
; SFTODO: Do we have to preserve AC/AD here? It obviously depends on how we're called, but this is transient command space and we're allowed to corrupt it if we're implementing a * command.
.copyYxToVariableMainRamSubroutine
{
.L9F33     LDA L00AD
            PHA
            LDA L00AC
            PHA
            STX L00AC
            STY L00AD
            LDY #variableMainRamSubroutineMaxSize - 1
.L9F3F      LDA (L00AC),Y
            STA variableMainRamSubroutine,Y
            DEY
            BPL L9F3F
            PLA
            STA L00AC
            PLA
            STA L00AD
            RTS
}

; Prepare for a data transfer between main and sideways RAM, handling case where
; "main" RAM is in parasite, and leave a suitable transfer subroutine at
; variableMainRamSubroutine.
.prepareMainSidewaysRamTransfer
; SFTODO: I am assuming prvOswordBlockCopy has always been through adjustPrvOsword42Block when this code is called
{
.L9F4E      BIT prvOswordBlockCopy + 5                                                              ;test high bit of 32-bit main memory address
            BMI notTube
            BIT tubePresenceFlag								;check for Tube - &00: not present, &ff: present
            BPL notTube
            LDA #&FF
            STA prvTubeReleasePending
.L9F5D      LDA #tubeEntryClaim + tubeClaimId
            JSR tubeEntry
            BCC L9F5D
            LDA prvOswordBlockCopy + 2                                                              ;get byte 0 of 32-bit main memory address
            STA L0100
            LDA prvOswordBlockCopy + 3                                                              ;get byte 1 of 32-bit main memory address
            STA L0101
            LDA prvOswordBlockCopy + 4                                                              ;get byte 2 of 32-bit main memory address
            STA L0102
            LDA prvOswordBlockCopy + 5                                                              ;get byte 3 of 32-bit main memory address
            STA L0103
            LDA prvOswordBlockCopy                                                                  ;get function
            EOR #&80
            ROL A
            LDA #&00
            ROL A
            ; At this point b0 of A has !b7 of function, all other bits of A
            ; clear. SFTODO: We have ignored b6 of function - is that safe? do
            ; we just not support pseudo-addresses? I don't think this is the
            ; same as the pseudo to absolute bank conversion done inside
            ; checkRamBankAndMakeAbsolute - that converts W=10->4 (for example),
            ; I *think* pseudo-addresses make the 64K of SWR look like a flat
            ; memory space. I could be wrong, I can't find any documentation on
            ; this right now.
            ; A=0 means multi-byte transfer, parasite to host
            ; A=1 means multi-byte transfer, host to parasite
            ; So this has converted the function into the correct transfer type.
            LDX #lo(L0100)
            LDY #hi(L0101)
            JSR tubeEntry

            LDX #lo(tubeTransferTemplate)
            LDY #hi(tubeTransferTemplate)
            JSR copyYxToVariableMainRamSubroutine					;relocate &32 bytes of code from &9EF9 to &03A7
            BIT prvOswordBlockCopy                                                                  ;test function
            BPL rts                                                                                 ;if this is read (from sideways RAM) we're done

            ; Patch the tubeTransfer code at variableMainRamSubroutine for writing (to sideways RAM) instead of reading.
            LDY #tubeTransferTemplateReadSwrEnd - tubeTransferTemplateReadSwr - 1
.L9F9A      LDA tubeTransferTemplateWriteSwr,Y
            STA variableMainRamSubroutine + (tubeTransferTemplateReadSwr - tubeTransferTemplate),Y
            DEY
            BPL L9F9A
.rts        RTS

.notTube
.L9FA4      LDA #&00
            STA prvTubeReleasePending
            LDX #lo(mainRamTransferTemplate)
            LDY #hi(mainRamTransferTemplate)
            JSR copyYxToVariableMainRamSubroutine					;relocate &32 bytes of code from &9ED9 to &03A7
            BIT prvOswordBlockCopy                                                                  ;test function
            BPL rts2                                                                                ;if this is read (from sideways RAM) we're done
            ; Patch the code at variableMainRamSubroutine to swap the operands
            ; of LDA and STA, thereby swapping the transfer direction.
            LDA #transientOs4243MainAddr
            STA variableMainRamSubroutine + (mainRamTransferTemplateLdaStaPair1 + 1 - mainRamTransferTemplate)
            STA variableMainRamSubroutine + (mainRamTransferTemplateLdaStaPair2 + 1 - mainRamTransferTemplate)
            LDA #transientOs4243SwrAddr
            STA variableMainRamSubroutine + (mainRamTransferTemplateLdaStaPair1 + 3 - mainRamTransferTemplate)
            STA variableMainRamSubroutine + (mainRamTransferTemplateLdaStaPair2 + 3 - mainRamTransferTemplate)
.rts2       RTS
}

;Relocation code then check for RAM banks.
; SFTODO: "Using..." part of name is perhaps OTT, but it might be important to "remind" us that this tramples over variableMainRamSubroutine - perhaps change later once more code is labelled up
.testRamUsingVariableMainRamSubroutine
{
.L9FC6      TXA
            PHA
            LDX #lo(testRamTemplate)
            LDY #hi(testRamTemplate)
            JSR copyYxToVariableMainRamSubroutine								;relocate &32 bytes of code from &9E0A to &03A7
            PLA
            JMP variableMainRamSubroutine								;Call relocated code
}
			
;this routine is called by osword42 and osword43
;
;00F0 contains X reg for most recent OSBYTE/OSWORD
;00F1 contains Y reg for most recent OSBYTE/OSWORD
;where X contains low byte of the parameter block address
;and   Y contains high byte of the parameter block address. 

.copyOswordDetailsToPrv
{
.L9FD3      JSR PrvEn								;switch in private RAM
            LDA oswdbtX								;get value of X reg
            STA prvOswordBlockOrigAddr							;and save to private memory &8230
            LDA oswdbtY								;get value of Y reg
            STA prvOswordBlockOrigAddr							;and save to private memory &8230  <-This looks wrong. Should this be &8231??? SFTODO: Looks odd indeed, maybe prvOswordBlockOrigAddr is never actually used?! (I haven't checked yet)
            LDY #prvOswordBlockCopySize - 1
.L9FE2      LDA (oswdbtX),Y								;copy the parameter block from its current location in memory
            STA prvOswordBlockCopy,Y							;to private memory &8220..&822F
            DEY									;total of 16 bytes
            BPL L9FE2
            RTS
}
			
; SFTODO: Could we move JSR PrvEn to L9FF8 before the STA and save three bytes by not duplicating it for srsave and srload? Note that PrvEn preserves A.
{
; SFTODO: *SRSAVE seems quite badly broken, I think because of problems with
; OSWORD &43.
; "*SRSAVE FOO A000 C000 4 Q" generates "Bad address" and saves nothing.
; "*SRSAVE FOO A000 C000 4" does seem to create the file correctly but then
; generates a "Bad address" error.
; SFTODO: Ken has pointed out those commands are (using Integra-B *SRSAVE conventions) trying to save one byte past the end of sideways RAM, hence "Bad address". I don't know if we should consider changing this to be more Acorn DFS SRAM utils-like in a new version of IBOS or not, but those actual commands do work fine if the end address is fixed. (We could potentially quibble about whether it's right that one of those error-generating command creates an empty file and the other doesn't, but I don't think this is a big deal, and I have no idea what Acorn DFS does either.)
;*SRSAVE Command
.^srsave	  JSR PrvEn								;switch in private RAM
            LDA #&00								;function "save absolute"
            JMP L9FF8
			
;*SRLOAD Command
.^srload	  JSR PrvEn								;switch in private RAM
            LDA #&80								;function "load absolute"
.L9FF8      STA prvOswordBlockCopy
            JSR getSrsaveLoadFilename
            JSR parseOsword4243BufferAddress
            BIT prvOswordBlockCopy							;function
            BMI notSave
            JSR parseOsword4243Length
	  ; SFTODO: Once the code is all worked out for both OSWORD &42 and &43, it's probably best to define constants e.g. prvOswordBlockCopyBufferLength = prvOswordBlockCopy + 6 and use those everywhere, instead of relying on comments on each line.
            LDA prvOswordBlockCopy + 6							;low byte of buffer length
            STA prvOswordBlockCopy + 10							;low byte of data length
            LDA prvOswordBlockCopy + 7							;high byte of buffer length
            STA prvOswordBlockCopy + 11							;high byte of data length
.notSave    JSR parseBankNumberIfPresent
            JSR parseSrsaveLoadFlags
            LDA prvOswordBlockCopy + 2							;byte 0 of "buffer address" we parsed earlier
            STA prvOswordBlockCopy + 8							;low byte of sideways start address
            LDA prvOswordBlockCopy + 3							;byte 1 of "buffer address" we parsed earlier
            STA prvOswordBlockCopy + 9							;high byte of sideways start address
            BIT prvOswordBlockCopy + 7
            JMP osword43Internal
}

; Fix up an adjusted OSWORD &43 buffer at prvOswordBlockCopy so:
; - it has the right start address and size if we're supposed to use PAGE-HIMEM
;   as the buffer
; - it has the actual file length populated if we're doing a write to sideways
;   RAM (the user-supplied one is ignored for OSWORD &43)
; SFTODO: I am assuming (probably true) this is used only by OSWORD 43 and
; therefore block is the adjusted 43 block
; SFTODO: Not a perfect name but will do for now
; SFTODO: This has only one caller
.adjustOsword43LengthAndBuffer
{
osfileBlock = L02EE
            ; Although OSWORD &43 doesn't use 32-bit addresses, we want to be able to use prepareMainSidewaysRamTransfer to implement OSWORD &43 and that does respect the full 32-bit address, so we need to patch the OSWORD block to indicate the I/O processor for the sideways address.
.^LA02D      LDA #&FF
            STA prvOswordBlockCopy + 4                                                    ;SFTODO: what's this? do we ever use it? maybe setting (non-existent) high word of address to host, just in case??
            STA prvOswordBlockCopy + 5                                                    ;SFTODO: ditto
            BIT prvOswordBlockCopy + 7                                                    ;high byte of buffer length
            BPL bufferNotPageToHimem
	  ; SFTODO: I think the stores here to block+6/7 show that these *are* supposed to be the buffer length
            LDA #osbyteReadWriteOshwm
            LDX #&00
            STX prvOswordBlockCopy + 2                                                    ;low byte of (16-bit) buffer address
            STX prvOswordBlockCopy + 6                                                    ;low byte of buffer length
            LDY #&FF
            JSR OSBYTE
            STX prvOswordBlockCopy + 3                                                    ;high byte of (16-bit) buffer address
            LDA #osbyteReadHimem
            JSR OSBYTE
            TYA
            SEC
            SBC prvOswordBlockCopy + 3                                                    ;high byte of (16-bit) buffer address (=PAGE)
            STA prvOswordBlockCopy + 7                                                    ;high byte of buffer length
.bufferNotPageToHimem
.LA059      BIT prvOswordBlockCopy                                                        ;function
            BPL readFromSwr
            LDA prvOswordBlockCopy + 12                                                   ;low byte of filename in I/O processor
            STA osfileBlock
            LDA prvOswordBlockCopy + 13                                                   ;high byte of filename in I/O processor
            STA osfileBlock + 1
            LDX #lo(osfileBlock)
            LDY #hi(osfileBlock)
            LDA #osfileReadInformation
            JSR OSFILE
            CMP #&01
            BNE errorNotFoundIndirect
	  ; SFTODO: And following on from above, these stores to block+10/11 do suggest it really is meant to the be the data length
            LDA osfileBlock + osfileReadInformationLengthOffset
            STA prvOswordBlockCopy + 10                                                   ;low byte of data length
            LDA osfileBlock + osfileReadInformationLengthOffset + 1
            STA prvOswordBlockCopy + 11                                                   ;high byte of data length
.readFromSwr
.LA083      RTS
}

.errorNotFoundIndirect
{
.LA084      JMP errorNotFound
}

; Open file pointed to by prvOswordBlockCopy in OSFIND mode A, generating a "Not Found" error if it fails.
; After a successful call file handle is stored at L02EE.
; SFTODO: Perhaps rename openOswordFile or similar, as I suspect there are other
; file-opening calls (e.g. *CREATE) in IBOS
.openFile
{
.LA087      LDX prvOswordBlockCopy + 12                                                   ;low byte of filename in I/O processor
            LDY prvOswordBlockCopy + 13                                                   ;high byte of filename in I/O processor
            JSR OSFIND
            CMP #&00
            BEQ errorNotFoundIndirect
            STA L02EE
            RTS
}

.closeHandleL02EE
{
.LA098      LDA #osfindClose
            LDY L02EE
            JMP OSFIND
}
			
;OSWORD &42 (66) - Sideways RAM transfer
;
;A selects an OSWORD routine.
;X contains low byte of the parameter block address.
;Y contains high byte of the parameter block address. 
;
;http://beebwiki.mdfs.net/OSWORD_%2642
;
;On entry:
; XY+0   =function
; XY!1   =main memory address
; XY+5..6=data length
; XY?7   =ROM number &00..&0F or &10..&13 for banks W, X, Y, Z
; XY+8..9=sideways address
;
;The functions are:
;&00 - Read from absolute address
;&40 - Read from pseudo-address
;&80 - Write to absolute address
;&C0 - Write to pseudo-address

.osword42
{
	  JSR copyOswordDetailsToPrv						;copy osword42 paramter block to Private memory &8220..&822F. Copy address of original block to Private memory &8230..&8231
            JSR adjustPrvOsword42Block						;convert pseudo RAM bank to absolute and shuffle parameter block
.^LA0A6      JSR getAddressesAndLengthFromPrvOswordBlockCopy
            BCS LA0B1 ; SFTODO: I don't believe this branch can ever be taken
            JSR prepareMainSidewaysRamTransfer
            JSR doTransfer
.LA0B1      PHP
            BIT prvTubeReleasePending
            BPL LA0BC
            LDA #tubeEntryRelease + tubeClaimId
            JSR tubeEntry
.LA0BC      JMP L9983
}

;SFTODOWIP
; SFTODO: I suspect this code could be rewritten more compactly using techniques described here: http://6502.org/tutorials/compare_beyond.html#4.2
; SFTODO: Do any callers actually use A/Y on return? My initial trace through OSWORD &43 load-via-small-buffer suggests that code doesn't, just the carry flag. OK, decreaseDataLengthAndAdjustBufferLength does use the A/Y return values, which suggests to me there may be a bug if we can go down the LA0D4 branch (*probably* happens if buffer is not a whole number of pages, but not thought through in detail)
.SFTODOSortOfCalculateWouldBeDataLengthMinusBufferLength
{
.LA0BF      SEC
            LDA prvOswordBlockCopy + 10                                                   ;low byte of "data length", actually buffer length
            SBC prvOswordBlockCopy + 6                                                    ;low byte of buffer length
            PHP
            TAY
            LDA prvOswordBlockCopy + 11                                                   ;high byte of "data length", actually buffer length
            SBC prvOswordBlockCopy + 7                                                    ;high byte of buffer length
            BEQ LA0D4         ; SFTODO: save-with-buffer will always branch here, because of bug (?) copying buffer length as save length
            TAX
            PLA                                                                           ;discard stacked flags
            TXA
            ; SFTODO: returning with AY containing "data length" - buffer length, carry set iff "data length" > buffer length
.rts        RTS

.LA0D4      TXA                                                                           ;we will return with X on entry in A SFTODO:!? if we *didn't* do this, A would be 0 and it would make sense that AY is the return value which is the number of bytes
            PLP
                                                                                          ;all the returns below have Y="data length"-buffer length (it's an 8-bit quantity, but SFTODO: I don't know how our caller knows that - it would make more sense if we returned with A=0, but we don't)
            BEQ LA0DA                                                                     ;return with carry clear if "data length" == buffer length
            BCS rts                                                                       ;return with carry set if "data length" > buffer length
.LA0DA      CLC                                                                           ;return with carry clear if "data length" < buffer length
            RTS
}

;SFTODOWIP
; SFTODO: Slightly optimistic summary based on partial understanding of code: Subtract buffer length from OSWORD block data length, adjusting the buffer length if we're at the end of the file and must not read an entire buffer to do the final chunk of the transfer.
; Returns with carry set iff there's no more data to transfer ("data length" is 0).
.decreaseDataLengthAndAdjustBufferLength
{
.LA0DC      LDA prvOswordBlockCopy + 10                                                  ;low byte of "data length", actually buffer length
            ORA prvOswordBlockCopy + 11                                                   ;high byte of "data length", actually buffer length
            BEQ LA108
            ; SFTODO: Can this go wrong if the result is negative? We don't check carry after calling SFTODOSortOfCalculateWouldBeDataLengthMinusBufferLength. Maybe this can't happen, but not immediately obvious.
            JSR SFTODOSortOfCalculateWouldBeDataLengthMinusBufferLength
            STY prvOswordBlockCopy + 10                                                   ;low byte of "data length", actually buffer length
            STA prvOswordBlockCopy + 11                                                   ;high byte of "data length", actually buffer length
            JSR SFTODOSortOfCalculateWouldBeDataLengthMinusBufferLength
            BCS remainingDataLargerThanBuffer
            ; The remaining data will fit in the buffer, so shrink the buffer length so we transfer exactly the right amount of data on the next chunk.
.^copySFTODOWouldBeDataLengthOverBufferLengthAndZeroWouldBeDataLength
.LA0F2      LDA prvOswordBlockCopy + 10                                                  ;low byte of "data length", actually buffer length
            STA prvOswordBlockCopy + 6                                                    ;low byte of buffer length
            LDA prvOswordBlockCopy + 11                                                   ;high byte of "data length", actually buffer length
            STA prvOswordBlockCopy + 7                                                    ;high byte of buffer length
            ; SFTODO: It's probably right when you see the whole loop structure, but it feels a bit premature to be setting the data length to 0 (as the next three lines do), surely we should wait until we've done the transfer and the test above at LA0DC realises the result is 0?
            LDA #&00
            STA prvOswordBlockCopy + 10                                                   ;low byte of data length SFTODO: or whatever it's appropriate to call it given the probably bug and this munging
            STA prvOswordBlockCopy + 11                                                   ;high byte of data length SFTODO: ditto
.remainingDataLargerThanBuffer
.LA106      CLC
            RTS
			
.LA108      SEC
            RTS
}

; SFTODO: Fairly sure this is only used within OSWORD &43 and so have used its adjusted osword block in comments
; SFTODO: This sets up an OSGBPB block and calls OSGBPB, A is OSGBPB reason code on entry
.doOsgbpbForOsword
{
.LA10A      PHA
            LDA prvOswordBlockCopy + 2                                                    ;low byte of buffer address
            STA L02EF                                                                     ;low byte of 32-bit data address
            LDA prvOswordBlockCopy + 3                                                    ;high byte of buffer address
            STA L02F0
            LDA #&FF
            STA L02F1
            STA L02F2                                                                     ;high byte of 32-bit data address
            LDA prvOswordBlockCopy + 6                                                    ;low byte of buffer length
            STA L02F3                                                                     ;low byte of 32-bit length
            LDA prvOswordBlockCopy + 7                                                    ;high byte of buffer length
            STA L02F4
            LDA #&00
            STA L02F5
            STA L02F6                                                                     ;high byte of 32-bit length
            LDX #lo(L02EE)
            LDY #hi(L02EE)
            PLA
            JMP OSGBPB
}
			
;OSWORD &43 (67) - Load/Save into/from sideways RAM
;
;A selects an OSWORD routine.
;X contains low byte of the parameter block address.
;Y contains high byte of the parameter block address. 
;
;http://beebwiki.mdfs.net/OSWORD_%2643
;
;On entry:
; XY?0     =function as for OSWORD &42 (66)
; XY+1..2  =>filename in I/O processor
; XY?3     =ROM number as for OSWORD &42 (66)
; XY+4..5  =sideways start address
; XY+6..7  =data length - ignored on LOAD
; XY+8..9  =buffer address
; XY+10..11=buffer length. If the buffer address is zero, a
;  default buffer is used in private workspace. If the
;  buffer length is larger than &7FFF, then language
;  workspace from PAGE to HIMEM is used.

; SFTODOWIP
; SFTODO: I am thinking I probably need to set up a few example OSWORD &43 calls on paper and trace through the code to see what it would do in that concrete situation - the possible bug in the data length is making it extremely hard to think about this in the abstract
.osword43
{
	  JSR copyOswordDetailsToPrv					;copy osword43 paramter block to Private memory &8220..&822F. Copy address of original block to Private memory &8230..&8231
            JSR adjustPrvOsword43Block					;convert pseudo RAM bank to absolute and shuffle parameter block
            BIT tubePresenceFlag					;check for Tube - &00: not present, &ff: present
            BPL noTube 						;branch if tube not present
.LA146      LDA #tubeEntryClaim + tubeClaimId				;tube present code
            JSR tubeEntry
            BCC LA146
            ; The following code is copying the CR-terminated "filename in I/O
            ; processor" across from the parasite into the host at L0700.
            ; SFTODO: This seems wrong, although I can't find any OSWORD &43
            ; docs right now to check. BeebWiki says this is *in I/O processor*,
            ; so presumably any client code running on the tube will have poked
            ; the data into the host, and IBOS is now going to copy from the
            ; corresponding address in the parasite where there's probably just
            ; junk. IBOS is also trampling all over language workspace in page
            ; 7; since the tube host code is the "current language" this is
            ; *probably* OK in practice, but I think it's strictly speaking
            ; *incorrect.
            LDA prvOswordBlockCopy + 12
            STA L0100
            LDA prvOswordBlockCopy + 13
            STA L0101
            LDA #&00
            STA L0102
            STA L0103
            LDX #lo(L0100)
            LDY #hi(L0100)
            JSR tubeEntry                                                       ;A=0 => multi-byte transfer, parasite to host
            LDY #&00
.LA16A      BIT SHEILA+&E4
            BPL LA16A
            LDA SHEILA+&E5
            STA L0700,Y
            CMP #vduCr
            BEQ LA17C
            INY
            BNE LA16A
.LA17C      LDA #tubeEntryRelease + tubeClaimId
            JSR tubeEntry
            ; Now patch up the OSWORD block so it refers to the data we just
            ; copied across from the parasite. SFTODO: But as noted above, I'm
            ; not sure we should have done that at all. This makes sense if we
            ; interpret the filename pointer in the OSWORD block as "in the
            ; language processor", *but* there are only two bytes allocated for
            ; it, so I don't think that's really reasonable - what if this is
            ; being called from an ARM copro, or an 80186, etc - they all have
            ; >64K of address space? *Maybe* 1770 DFS does this too and BeebWiki
            ; has wrong info, but I suspect IBOS is wrong here. OK, having now
            ; seen Master Reference Manual (thansk Ken!) it does say "in main
            ; RAM". To be super cautious we should maybe write a test program
            ; and compare behaviour with tube on a) a B+/Master with Acorn DFS
            ; and IBOS b) Integra-B, but I think this is an IBOS bug. Which is
            ; good, because the fix is simply to get rid of all this tube code
            ; (not in the transfer, just here), freeing up space at the same
            ; time - win-win!
            LDA #lo(L0700)
            STA prvOswordBlockCopy + 12
            LDA #hi(L0700)
            STA prvOswordBlockCopy + 13
.noTube
.^osword43Internal
.LA18B      JSR adjustOsword43LengthAndBuffer
            LDA prvOswordBlockCopy + 6                                                              ;low byte of buffer length
            ORA prvOswordBlockCopy + 7                                                              ;high byte of buffer length
            BNE bufferLengthNotZero
            BIT prvOswordBlockCopy                                                                  ;function
            BPL readFromSwr
            ; We're writing to sideways RAM.
            LDA #osfindOpenInput
            LDX #lo(loadSwrTemplate)
            LDY #hi(loadSwrTemplate)
            JMP LA1AA								;Relocate code from &9EAE

.readFromSwr
.LA1A4      LDA #osfindOpenOutput
            LDX #lo(saveSwrTemplate)
            LDY #hi(saveSwrTemplate)
.LA1AA      PHA
            JSR copyYxToVariableMainRamSubroutine								;relocate &32 bytes of code from either &9E83 or &9EAE to &03A7
            ; SFTODO: Is this code correct even ignoring the possible bug at
            ; adjustPrvOsword43Block? We seem to be trying to treat the data
            ; length as the buffer length - what if the data is longer than the
            ; buffer? Just possibly the "bug" is a misguided attempt to work
            ; around that. Speculation really as I still don't have the whole
            ; picture.
            LDA prvOswordBlockCopy + 10                                                             ;low byte of buffer length (SFTODO: bug? see adjustPrvOsword43Block)
            STA prvOswordBlockCopy + 6                                                              ;low byte of buffer length
            LDA prvOswordBlockCopy + 11                                                             ;high byte of buffer length (SFTODO: bug? see adjustProvOsword43Block)
            STA prvOswordBlockCopy + 7                                                              ;high byte of buffer length
            PLA
            JSR openFile
            JSR getAddressesAndLengthFromPrvOswordBlockCopy
            JSR doTransfer
            JMP LA22B

.bufferLengthNotZero
; SFTODO: Does this assume the entire file fits into the buffer? Is that OK? Maybe 1770 DFS does the same?
.LA1C7      JSR prepareMainSidewaysRamTransfer
            JSR getAddressesAndLengthFromPrvOswordBlockCopy
            BIT prvOswordBlockCopy                                                                  ;function
	  ; SFTODO: Can we just use BPL bufferLengthNotZeroReadFromSwr? Probably too far...
            BMI bufferLengthNotZeroWriteToSwr
            JMP bufferLengthNotZeroReadFromSwr

.bufferLengthNotZeroWriteToSwr
.LA1D5      JSR SFTODOSortOfCalculateWouldBeDataLengthMinusBufferLength
            BCS dataLengthGreaterThanBufferLength
            JSR copySFTODOWouldBeDataLengthOverBufferLengthAndZeroWouldBeDataLength
            LDA prvOswordBlockCopy + 12                                                             ;low byte of filename in I/O processor
            STA L02EE
            LDA prvOswordBlockCopy + 13                                                             ;high byte of filename in I/O processor
            STA L02EF
            LDA prvOswordBlockCopy + 2                                                              ;low byte of buffer address
            STA L02F0
            LDA prvOswordBlockCopy + 3                                                              ;high byte of buffer address
            STA L02F1
            LDA #&00
            STA L02F4
            LDA #&FF                                                                                ;osfileLoad
            STA L02F2
            STA L02F3
            LDX #lo(L02EE)
            LDY #hi(L02EE)
            JSR OSFILE
            LDA #&00
            STA L02EE
            JMP LA21B

.dataLengthGreaterThanBufferLength
.LA211      LDA #osfindOpenInput
            JSR openFile
.LA216      LDA #osgbpbReadCurPtr
            JSR doOsgbpbForOsword
.LA21B      JSR getBufferAddressAndLengthFromPrvOswordBlockCopy
            JSR doTransfer
            JSR decreaseDataLengthAndAdjustBufferLength
            BCC LA216
            LDA L02EE
            BEQ LA22E
.LA22B      JSR closeHandleL02EE
.LA22E      BIT prvOswordBlockCopy                                                                  ;function
            BPL PrvDisexitScIndirect                                                                ;branch if read
            BVS PrvDisexitScIndirect                                                                ;branch if pseudo-address
            LSR prvOswordBlockCopy                                                                  ;function
            ; SFTODO: Why are we testing the low bit of 'function' here? The defined values always have this 0. Is something setting this internally to flag something?
            BCC LA240 ; SFTODO: always branch? At least during an official user-called OSWORD &43 we will, as low bit should always be 0 according to e.g. Master Ref Manual
            LDA prvOswordBlockCopy + 1                                                              ;absolute ROM number
            JSR LA499
.LA240      JSR PrvEn								;switch in private RAM
            LSR prvOswordBlockCopy
            ; SFTODO: And again, we're testing what was b1 of 'function' before we started shifting - why? Is this an internal flag?
            BCC PrvDisexitScIndirect
.LA248      LDA prvOswordBlockCopy + 1                                                              ;absolute ROM number
            JMP LA4FE

.PrvDisexitScIndirect
.LA24E      JMP PrvDisexitSc

.bufferLengthNotZeroReadFromSwr
.LA251      JSR SFTODOSortOfCalculateWouldBeDataLengthMinusBufferLength
            BCS LA261
            JSR copySFTODOWouldBeDataLengthOverBufferLengthAndZeroWouldBeDataLength
            LDA #&00
            STA L02EE ; SFTODO: I *suspect* L02EE is playing its file handle role here
            JMP LA266 ; SFTODO: we just set A=0 so we could BEQ to save a byte
			
.LA261      LDA #osfindOpenOutput
            JSR openFile
.LA266      JSR getBufferAddressAndLengthFromPrvOswordBlockCopy
            JSR doTransfer
            LDA L02EE ; SFTODO: almost certainly playing its file handle role here
            BEQ LA27E
            LDA #&02
            JSR doOsgbpbForOsword
            JSR decreaseDataLengthAndAdjustBufferLength
            BCC LA266
            JMP LA22B
			
.LA27E      LDA prvOswordBlockCopy + 12
            STA L02EE
            LDA prvOswordBlockCopy + 13
            STA L02EF
            LDA prvOswordBlockCopy + 2
            STA L02F8
            LDA prvOswordBlockCopy + 3
            STA L02F9
            LDA prvOswordBlockCopy + 8
            STA L02F0
            STA L02F4
            LDA prvOswordBlockCopy + 9
            STA L02F1
            STA L02F5
            LDA #&FF
            STA L02F2
            STA L02F3
            STA L02F6
            STA L02F7
            STA L02FA
            STA L02FB
            STA L02FE
            STA L02FF
            CLC
            LDA prvOswordBlockCopy + 2
            ADC prvOswordBlockCopy + 6
            STA L02FC
            LDA prvOswordBlockCopy + 3
            ADC prvOswordBlockCopy + 7
            STA L02FD
            LDA #&00
            LDX #&EE
            LDY #&02
            JSR OSFILE
.^PrvDisexitSc
.LA2DE      JSR PrvDis								;switch out private RAM
            JMP exitSC								;Exit Service Call
			
.^LA2E4      JSR parseRomBankList
            BCC LA2F9
            BVC LA2F6
.^badId
.LA2EB      JSR raiseError								;Goto error handling, where calling address is pulled from stack

			EQUB &80
			EQUS "Bad id", &00

.LA2F6      JMP syntaxError

.LA2F9      RTS
}

;*INSERT Command
.insert     JSR LA2E4								;Error check input data
            LDX #&06								;get *INSERT status
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            ORA L00AE								;update *INSERT status
            JSR writeUserReg								;Write to RTC clock User area. X=Addr, A=Data
            LDX #&07
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            ORA L00AF
            JSR LA31A								;Check for Immediate 'I' flag
            BNE LA317								;Exit if not immediate
            INY
            JSR LA49C								;Initialise inserted ROMs
.LA317      JMP exitSC								;Exit Service Call

.LA31A      JSR writeUserReg								;Write to RTC clock User area. X=Addr, A=Data
            JSR findNextCharAfterSpace								;find next character. offset stored in Y
            LDA (L00A8),Y
            AND #&DF								;Capitalise
            CMP #&49								;and check for 'I' (Immediate)
            RTS

;*UNPLUG Command
.unplug	  JSR LA2E4								;Error check input data
            JSR invertTransientRomBankMask								;Invert all bits in &AE and &AF
            LDX #&06								;INSERT status for ROMS &0F to &08
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            AND L00AE
            JSR writeUserReg								;Write to RTC clock User area. X=Addr, A=Data
            LDX #&07								;INSERT status for ROMS &07 to &00
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            AND L00AF
            JSR LA31A
            BNE LA347
            INY
            JSR LA4C5
.LA347      JMP exitSC								;Exit Service Call

.LA34A	  EQUB &00								;ROM at Banks 0 & 1
	  EQUB &00								;ROM at Banks 2 & 3
	  EQUB &04								;Check for RAM at Banks 4 & 5
	  EQUB &08								;Check for RAM at Banks 6 & 7
	  EQUB &10								;Check for RAM at Banks 8 & 9
	  EQUB &20								;Check for RAM at Banks A & B
	  EQUB &40								;Check for RAM at Banks C & D
	  EQUB &80								;Check for RAM at Banks E & F

;*ROMS Command
.roms	  LDA #&0F								;Start at ROM &0F
            STA L00AA								;Save ROM number at &AA
.LA356      JSR LA360								;Get and print details of ROM
            DEC L00AA								;Next ROM
            BPL LA356								;Until ROM &00
            JMP LA537
			
;Get and print details of ROM at location &AA
.LA360      LDA L00AA								;Get ROM Number
            CLC
            JSR printADecimal								;Convert binary number to numeric characters and write characters to screen
            JSR printSpace								;write ' ' to screen
            LDA #'('								;'('
            JSR OSWRCH								;write to screen
            LDA L00AA								;Get ROM Number
	  LSR A
            TAY
            LDX #&7F								;read RAM installed in bank flag from private &83FF
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            AND LA34A,Y								;Get data from lookup table
            BNE LA380								;Branch if RAM
            LDA #&20								;' '
            BNE LA38D								;jump to write to screen
.LA380      LDX L00AA								;get ROM number
            JSR testRamUsingVariableMainRamSubroutine								;check if ROM is WP. Will return with Z set if writeable
            PHP
            LDA #'E'								;'E' (Enabled)
            PLP
            BEQ LA38D								;jump to write to screen
            LDA #'P'								;'P' (Protected)
.LA38D      JSR OSWRCH								;write to screen
            JSR PrvEn								;switch in private RAM
            LDX L00AA								;Get ROM Number
            LDA L02A1,X								;get ROM Type
            LDY #' '								;' '
            AND #&FE								;bit 0 of ROM Type is undefined, so mask out
            BNE LA3BC								;if any other bits set, then ROM exists so skip code for Unplugged ROM check, and get and write ROM details
            LDY #&55								;'U' (Unplugged)
            JSR PrvEn								;switch in private RAM
            LDA prv83+&2C,X;								;get backup copy of ROM Type
            JSR PrvDis								;switch out private RAM
            BNE LA3BC								;if any bits set, then unplugged ROM exists so get and write ROM details
            JSR printSpace								;write ' ' to screen in place of 'U'
            JSR printSpace								;write ' ' to screen in place of 'S'
            JSR printSpace								;write ' ' to screen in place of 'L'
            LDA #')'								;')'
            JSR OSWRCH								;write to screen
            JMP OSNEWL								;new line and return
			
.LA3BC      PHA									;save ROM Type
            TYA									;either ' ' for inserted, or 'U' for unplugged, depending on where called from
            JSR OSWRCH								;write to screen
            LDX #'S'								;'S' (Service)
            PLA									;recover ROM Type
            PHA									;save ROM Type for further investigation
            BMI LA3C9								;check bit 7 (Service Entry exists) and write 'S' if set
            LDX #' '								;otherwise write ' '
.LA3C9      TXA
            JSR OSWRCH								;write either 'S' or ' ' to screen
            LDX #'L'								;'L' (Language)
            PLA									;recover ROM Type
            AND #&40								;check bit 6 (Language Entry exists)
            BNE LA3D6								;write 'L'
            LDX #' '								;otherwise write ' '
.LA3D6      TXA
            JSR OSWRCH								;write either 'L' or ' ' to screen
            LDA #')'
            JSR OSWRCH								;write to screen
            JSR printSpace								;write ' ' to screen
            LDA #&07
            STA L00F6
            LDA #&80
            STA L00F7								;Save address &8007 to &F6 / &F7 (copyright offset pointer)
            LDY L00AA								;Get ROM Number
            JSR OSRDRM								;read byte in paged ROM y from address located at &F6
            STA L00AB								;save copyright offset pointer
            LDA #&09
            STA L00F6								;Save address &8009 to &F6 / &F7 (title string)
.LA3F5      LDY L00AA								;Get ROM Number
            JSR OSRDRM								;read byte in paged ROM y
            BNE LA3FE								;0 indicates end of title string,
            LDA #' '								;so write ' ' instead
.LA3FE      JSR OSWRCH								;write to screen
            INC L00F6								;next character
            LDA L00F6
            CMP L00AB								;at copyright offset pointer (end of title string + version string)?
            BCC LA3F5								;loop if not.
            JMP OSNEWL								;otherwise finished for this rom so write new line and return

; Parse a list of bank numbers, returning them as a bitmask in transientRomBankMask. '*' can be used to indicate "everything but the listed banks". Return with C set iff at least one bit of transientRomBankMask is set.
.parseRomBankList
{
.LA40C      LDA #&00
            STA transientRomBankMask
            STA transientRomBankMask + 1
.LA412      JSR parseBankNumber
            BCS noBankNumber
            JSR addToRomBankMask
            JMP LA412
			
.noBankNumber
            LDA (transientCmdPtr),Y
            CMP #'*'
            BNE LA429
            BVS secRts ; branch if not at end of line SFTODO: isn't this redundant? We just successfully checked and found a '*' not a CR? So we'll never branch, right? Should we have checked this earlier (e.g. at .noBankNumber)? Have I just got confused?
            INY
            JSR invertTransientRomBankMask
.LA429      LDA transientRomBankMask
            ORA transientRomBankMask + 1
            BEQ secRts
            CLC
            RTS

; SFTODO: There's probably another copy of these two instructions we could re-use, though it might require shuffling code round and be more trouble than it's worth
.secRts
            SEC
            RTS
}

; Set 16-bit word at transientRomBankMask to 1<<A, i.e. set it to 0 except bit A. Y is preserved.
; SFTODO: Am I missing something, or wouldn't it be far easier just to do a 16-bit rotate left in a loop? Maybe that wouldn't be shorter. Maybe this is performance critical? (Doubt it)
; SFTODO: I suspect this is creating some sort of ROM bank mask, but that is speculation at moment so label may be misleading.
.createRomBankMask
{
.LA433      PHA
            LDA #&00
            STA transientRomBankMask
            STA transientRomBankMask + 1
            PLA
; Set bit A of the 16-bit word at transientRomBankMask. Y is preserved.
; SFTODO: Speculating this is ROM mask, hence label name, which may not be right.
.^addToRomBankMask
.LA43B      TAX
            TYA
            PHA
            TXA                                                                                     ;A is now same as on entry
            LDX #&00
            CMP #&08
            BCC LA447
            LDX #&01
.LA447      AND #&07
            TAY
            LDA #&00
            SEC
.LA44D      ROL A
            DEY
            BPL LA44D
            ORA transientRomBankMask,X
            STA transientRomBankMask,X
            PLA
            TAY
            RTS
}

; Parse a bank number from the command line, converting W-Z into the corresponding real bank numbers.
; Return with C clear if and only if we parsed a bank number, which will be in A.
; If C is set, V will be clear iff there was nothing left on the command line.
.parseBankNumber
{
; SFTODO: Would it be more compact to check for W-Z *first*, then use convertIntegerDefaultHex? This might only work if we do a "proper" upper case conversion, not sure.
.LA458      JSR findNextCharAfterSpace								;find next character. offset stored in Y
            BCS endOfLine
            LDA (transientCmdPtr),Y
            CMP #','
            BNE LA464
            INY
.LA464      JSR convertIntegerDefaultDecimal
            BCC parsedDecimalOK
            LDA (transientCmdPtr),Y
            AND #&DF                                                                                ;convert to upper case (imperfect but presumably good enough)
            CMP #'F'+1
            BCS LA47A
            CMP #'A'
            BCC LA492
            SBC #'A'-10
            JMP LA48B ; SFTODO: could probably do "BPL LA48B ; branch always" to save a byte
			
.LA47A      CMP #'Z'+1
            BCS LA492
            CMP #'W'
            BCC LA492
            SBC #'W'
            CLC
            ADC #prvPseudoBankNumbers - prv83
            TAX
            JSR readPrivateRam8300X								;read data from Private RAM &83xx (Addr = X, Data = A)
.LA48B      INY
.parsedDecimalOK
            CMP #&10
            BCS LA495
.endOfLine  CLV
            RTS
			
.LA492      SEC
            CLV
            RTS
			
.LA495      BIT rts ; set V
.rts        RTS
}

; SFTODO: This only has one caller
.LA499      JSR createRomBankMask
.LA49C      JSR PrvEn								;switch in private RAM


;Called by *INSERT Immediate (SFTODO: but note we also fall through into it from code above)
;Read ROM Type from ROM header and save to ROM Type Table and Private RAM
            LDY #&0F
.LA4A1      ASL transientRomBankMask
            ROL transientRomBankMask + 1
            BCC LA4BE
            LDA #&06								;set address pointer to &8006 - ROM Type
            STA L00F6								;address pointer into paged ROM
            LDA #&80
            STA L00F7								;address pointer into paged ROM
            TYA
            PHA
            JSR OSRDRM								;Read ROM Type from paged ROM
            TAX
            PLA
            TAY
            TXA
            STA L02A1,Y								;Save ROM Type to ROM Type table
            STA prv83+&2C,Y								;Save ROM Type to Private RAM copy of ROM Type table
.LA4BE      DEY
            BPL LA4A1
            JSR PrvDis								;switch out private RAM
            RTS
			
;Called by *UNPLUG Immediate
;Set all bytes in ROM Type Table to 0
.LA4C5      LDY #&0F
.LA4C7      ASL L00AE
            ROL L00AF
            BCS LA4D2
            LDA #&00
            STA L02A1,Y
.LA4D2      DEY
            BPL LA4C7
            RTS
			
;Invert all bits in &AE and &AF
.invertTransientRomBankMask
{
.LA4D6      LDA transientRomBankMask
            EOR #&FF
            STA transientRomBankMask
            LDA transientRomBankMask + 1
            EOR #&FF
            STA transientRomBankMask + 1
            RTS
}
			

;Assign default pseudo RAM banks to absolute RAM banks
;For OSMODEs, 0, 1, 3, 4 & 5: W..Z = 4..7
;For OSMODE 2: W..Z = 12..15

.LA4E3      JSR PrvEn								;switch in private RAM
            LDA prvOsMode								;read OSMODE
            LDX #&03								;a total of 4 pseudo banks
            LDY #&07								;for osmodes other than 2, absolute banks are 4..7
            CMP #&02								;check for osmode 2
            BNE LA4F3
            LDY #&0F								;if osmode is 2, absolute banks are 12..15
.LA4F3      TYA									;
            STA prvPseudoBankNumbers,X								;assign pseudo bank to the appropriate absolute bank
            DEY									;reduce absolute bank number by 1
            DEX									;reduce pseudo bank number by 1
            BPL LA4F3								;until all 4 pseudo banks have been assigned an appropriate absolute bank
            JMP PrvDis								;switch out private RAM

; SFTODO: This little fragment of code is only called once via JMP, can't it just be moved to avoid the JMP (and improve readability)?
.LA4FE      JSR createRomBankMask
            SEC
            PHP
            JMP LA513
			
{
;*SRWE Command
.^srwe      CLC
            BCC LA50A

;*SRWP Command
.^srwp      SEC
.LA50A      PHP
            JSR parseRomBankList
            BCC LA513
            JMP badId
			
.^LA513     LDX #&38
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            ORA L00AE
            PLP
            PHP
            BCC LA520
            EOR L00AE
.LA520      JSR writeUserReg								;Write to RTC clock User area. X=Addr, A=Data
            INX
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            ORA L00AF
            PLP
            BCC LA52E
            EOR L00AF
.LA52E      JSR writeUserReg								;Write to RTC clock User area. X=Addr, A=Data
            JSR PrvEn								;switch in private RAM
            JSR LA53D
.^LA537     JSR PrvDis								;switch out private RAM
            JMP exitSC								;Exit Service Call
}
			
.LA53D      LDX #&38
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            STA prv82+&52
            INX
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            PHP
            SEI
            LSR A
            ROR prv82+&52
            LSR A
            ROR prv82+&52
            ORA #&80
            STA SHEILA+&38
            LDA prv82+&52
            LSR A
            LSR A
            ORA #&40
            STA SHEILA+&38
            JSR LA664
            PLP
            RTS

;SPOOL/EXEC file closure warning - Service call 10
.service10	SEC
            JSR LA7A8
            BCS LA570
            JMP LA5B8
			
.LA570      LDA ramselCopy
            AND #&80
            STA ramselCopy

            JSR PrvEn								;switch in private RAM

            JSR LA53D

;copy ROM type table to Private RAM
            LDX #&0F
.LA580      LDA L02A1,X
            STA prv83+&2C,X
            DEX
            BPL LA580

            JSR PrvDis								;switch out private RAM

            LDX lastBreakType
            BEQ LA5B8
            LDA #&7A
            JSR OSBYTE
            CPX #&47
            BNE LA5B8
            LDA #&00
            STA L0287
            LDA #&FF
            STA L03A4

;Set all bytes in ROM Type Table and Private RAM to 0
            LDX #&0F
.LA5A6      CPX romselCopy
            BEQ LA5B2
            LDA #&00
            STA L02A1,X
            STA L0DF0,X
.LA5B2      DEX
            BPL LA5A6

            JMP LA5CE
			
.LA5B8      LDA #&00
            STA L03A4
            LDX #&06
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            STA L00AE
            LDX #&07
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            STA L00AF
            JSR LA4C5
.LA5CE      LDX #&41
            JSR readPrivateRam8300X								;read data from Private RAM &83xx (Addr = X, Data = A)
            EOR #&FF
            AND #&10
            TSX
            STA L0103,X
            JMP exitSCa								;restore service call parameters and exit
			
;Write contents from Private memory address &8000 to screen
.LA5DE      LDX #&00
.LA5E0      LDA prv80+&00,X
            BEQ LA5EE
            JSR OSASCI
            INX
            CPX prvOswordBlockCopy + 1
            BCC LA5E0
.LA5EE      RTS

;store #&05, #&84, #&44 and #&EB to addresses &8220..&8223, but why???
.LA5EF      LDA #&05
            STA prvOswordBlockCopy
            LDA #&84
            STA prvOswordBlockCopy + 1
            LDA #&44
            STA prvOswordBlockCopy + 2
            LDA #&EB
            STA prvOswordBlockCopy + 3
            RTS
			
.LA604      LDA #&00
            STA prv82+&4D
            LDX #&08
.LA60B      ASL A
            ROL prv82+&4D
            ASL prv82+&4B
            BCC LA61D
            CLC
            ADC prv82+&4A
            BCC LA61D
            INC prv82+&4D
.LA61D      DEX
            BNE LA60B
            STA prv82+&4C
            RTS
			
.LA624      LDX #&08
            LDA prv82+&4A
            STA prv82+&4D
            LDA prv82+&4B
            CMP prv82+&4C
            BCS LA646
.LA634      ROL prv82+&4D
            ROL A
            CMP prv82+&4C
            BCC LA640
            SBC prv82+&4C
.LA640      DEX
            BNE LA634
            ROL prv82+&4D
.LA646      RTS

;read from RTC RAM (Addr = X, Data = A)
.rdRTCRAM   PHP
            SEI
            JSR LA66C								;Set RTC address according to X
            LDA SHEILA+&3C								;Strobe out data
            JSR LA664
            PLP
            RTS
			
;write to RTC RAM (Addr = X, Data = A)
.wrRTCRAM   PHP
            JSR LA66C								;Set RTC address according to X
            STA SHEILA+&3C								;Strobe in data
            JSR LA664
            PLP
            RTS

.LA660      NOP
.LA661      NOP
            NOP
            RTS

.LA664      PHA
            LDA #&0D								;Select 'Register D' register on RTC: Register &0D
            JSR LA66C
            PLA
            RTS
			
.LA66C      SEI
            JSR LA661								;2 x NOP delay
            STX SHEILA+&38								;Strobe in address
            JMP LA660								;3 x NOP delay

;Read 'Seconds', 'Minutes' & 'Hours' from Private RAM (&82xx) and write to RTC
.LA676      LDX #&0A								;Select 'Register A' register on RTC: Register &0A
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            ORA #&70
            JSR wrRTCRAM								;Write data from A to RTC memory location X
            LDX #&0B								;Select 'Register B' register on RTC: Register &0B
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            AND #&70
            ORA #&86
            JSR wrRTCRAM								;Write data from A to RTC memory location X
            LDX #&00								;Select 'Seconds' register on RTC: Register &00
            LDA prvOswordBlockCopy + 15								;Get 'Seconds' from &822F
            JSR wrRTCRAM								;Write data from A to RTC memory location X
            LDX #&02								;Select 'Minutes' register on RTC: Register &02
            LDA prvOswordBlockCopy + 14								;Get 'Minutes' from &822E
            JSR wrRTCRAM								;Write data from A to RTC memory location X
            LDX #&04								;Select 'Hours' register on RTC: Register &04
            LDA prvOswordBlockCopy + 13								;Get 'Hours' from &822D
            JSR wrRTCRAM								;Write data from A to RTC memory location X
            LDX #&0A								;Select 'Register A' register on RTC: Register &0A
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            AND #&20
            JSR wrRTCRAM								;Write data from A to RTC memory location X
            LDX #userRegOsModeShx
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            LDX #&00
            AND #&10
            BEQ LA6BB
            LDX #&01
.LA6BB      STX prv82+&4E
            LDX #&0B								;Select 'Register B' register on RTC: Register &0B
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            AND #&7E
            ORA prv82+&4E
            JMP wrRTCRAM								;Write data from A to RTC memory location X
			
;Read 'Day of Week', 'Date of Month', 'Month' & 'Year' from Private RAM (&82xx) and write to RTC
.LA6CB      JSR LA775								;Check if RTC Update in Progress, and wait if necessary
            LDX #&06								;Select 'Day of Week' register on RTC: Register &06
            LDA prvOswordBlockCopy + 12								;Get 'Day of Week' from &822C
            JSR wrRTCRAM								;Write data from A to RTC memory location X
            INX									;Select 'Day of Month' register on RTC: Register &07
            LDA prvOswordBlockCopy + 11								;Get 'Day of Month' from &822B
            JSR wrRTCRAM								;Write data from A to RTC memory location X
            INX									;Select 'Month' register on RTC: Register &08
            LDA prvOswordBlockCopy + 10								;Get 'Month' from &822A
            JSR wrRTCRAM								;Write data from A to RTC memory location X
            INX									;Select 'Year' register on RTC: Register &09
            LDA prvOswordBlockCopy + 9								;Get 'Year' from &8229
            JSR wrRTCRAM								;Write data from A to RTC memory location X
            LDX #&35
            LDA prvOswordBlockCopy + 8
            JMP writeUserReg								;Write to RTC clock User area. X=Addr, A=Data

;Read 'Seconds', 'Minutes' & 'Hours' from RTC and Store in Private RAM (&82xx)
.LA6F3      JSR LA775								;Check if RTC Update in Progress, and wait if necessary
            LDX #&00								;Select 'Seconds' register on RTC: Register &00
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            STA prvOswordBlockCopy + 15								;Store 'Seconds' at &822F
            LDX #&02								;Select 'Minutes' register on RTC: Register &02
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            STA prvOswordBlockCopy + 14								;Store 'Minutes' at &822E
            LDX #&04								;Select 'Hours' register on RTC: Register &04
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            STA prvOswordBlockCopy + 13								;Store 'Hours' at &822D
            RTS

;Read 'Day of Week', 'Date of Month', 'Month' & 'Year' from RTC and Store in Private RAM (&82xx)
.LA70F      JSR LA775								;Check if RTC Update in Progress, and wait if necessary
            LDX #&06								;Select 'Day of Week' register on RTC: Register &06
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            STA prvOswordBlockCopy + 12								;Store 'Day of Week' at &822C
            INX									;Select 'Day of Month' register on RTC: Register &07
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            STA prvOswordBlockCopy + 11								;Store 'Day of Month' at &822B
            INX									;Select 'Month' register on RTC: Register &08
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            STA prvOswordBlockCopy + 10								;Store 'Month' at &822A
            INX									;Select 'Year' register on RTC: Register &09
.LA729      JSR rdRTCRAM								;Read data from RTC memory location X into A
            STA prvOswordBlockCopy + 9								;Store 'Year' at &8229
            JMP LB1E4

;Read 'Sec Alarm', 'Min Alarm' & 'Hr Alarm' from RTC and Store in Private RAM (&82xx)
.copyRtcAlarmToPrv
{
.LA732      JSR LA775								;Check if RTC Update in Progress, and wait if necessary
            LDX #&01								;Select 'Sec Alarm' register on RTC: Register &01
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            STA prvOswordBlockCopy + 15								;Store 'Sec Alarm' at &822F
            LDX #&03								;Select 'Min Alarm' register on RTC: Register &03
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            STA prvOswordBlockCopy + 14								;Store 'Min Alarm' at &822E
            LDX #&05								;Select 'Hr Alarm' register on RTC: Register &05
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            STA prvOswordBlockCopy + 13								;Store 'Hr Alarm' at &822D
            RTS
}

;Read 'Sec Alarm', 'Min Alarm' & 'Hr Alarm' from Private RAM (&82xx) and write to RTC
.copyPrvAlarmToRtc
{
.LA74E      JSR LA775								;Check if RTC Update in Progress, and wait if necessary
            LDX #&01								;Select 'Sec Alarm' register on RTC: Register &01
            LDA prvOswordBlockCopy + 15								;Get 'Sec Alarm' from &822F
            JSR wrRTCRAM								;Write data from A to RTC memory location X
            LDX #&03								;Select 'Min Alarm' register on RTC: Register &03
            LDA prvOswordBlockCopy + 14								;Get 'Min Alarm' from &822E
            JSR wrRTCRAM								;Write data from A to RTC memory location X
            LDX #&05								;Select 'Hr Alarm' register on RTC: Register &05
            LDA prvOswordBlockCopy + 13								;Get 'Hr Alarm' from &822D
            JMP wrRTCRAM								;Write data from A to RTC memory location X
}
			
.LA769      JSR LA70F								;Read 'Day of Week', 'Date of Month', 'Month' & 'Year' from RTC and Store in Private RAM (&82xx)
            JMP LA6F3								;Read 'Seconds', 'Minutes' & 'Hours' from RTC and Store in Private RAM (&82xx)
			
            JSR LA676								;Read 'Seconds', 'Minutes' & 'Hours' from Private RAM (&82xx) and write to RTC						***not used. nothing jumps into this code***
            JMP LA6CB								;Read 'Day of Week', 'Date of Month', 'Month' & 'Year' from Private RAM (&82xx) and write to RTC

;Wait until RTC Update in Progress	is complete		
.LA775      LDX #&0A								;Select 'Register A' register on RTC: Register &0A
.LA777      JSR LA660								;3 x NOP delay
            STX SHEILA+&38								;Strobe in address
            JSR LA660								;3 x NOP delay
            LDA SHEILA+&3C								;Strobe out data
            BMI LA777								;Loop if Update in Progress (if MSB set)
            RTS

;Initialisation lookup table for RTC registers &00 to &09
.LA786		EQUB &00								;Register &00 - Seconds:	 	00
		EQUB &00								;Register &01 - Sec Alarm:	 	00
		EQUB &00								;Register &02 - Minutes:	 	00
		EQUB &00								;Register &03 - Min Alarm:	 	00
		EQUB &00								;Register &04 - Hours:		00
		EQUB &00								;Register &05 - Hr Alarm:	 	00
;		EQUB &07								;Register &06 - Day of Week:		Saturday	Note: This was set to 2 (Mon), which was correct when century was 1900. Changed in IBOS 1.21
		EQUB &02								;Register &06 - Day of Week:		Monday
		EQUB &01								;Register &07 - Day of Month:		01
		EQUB &01								;Register &08 - Month:		January
		EQUB &00								;Register &09 - Year:		00

;Stop Clock and Initialise RTC registers &00 to &0B
.LA790      LDX #&0B								;Select 'Register B' register on RTC: Register &0B
            LDA #&86								;Stop Clock, Set Binary mode, Set 24hr mode
            JSR wrRTCRAM								;Write data from A to RTC memory location X
            DEX									;Select 'Register A' register on RTC: Register &0A
            LDA #&E0								;Divider Off, Invalid write 'Update in Progress' bit!
            JSR wrRTCRAM								;Write data from A to RTC memory location X
            DEX									;Start at Register &09
.LA79E      LDA LA786,X								;Read data from table
            JSR wrRTCRAM								;Write data from A to RTC memory location X
            DEX									;Next register
            BPL LA79E								;Until <0
            RTS									;Exit

.LA7A8      BCS LA7C2
            LDX #&33
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            AND #&40
            LSR A
            STA L00AE
            LDX #&0B								;Select 'Register B' register on RTC: Register &0B
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            ORA #&08
            ORA L00AE
            JSR wrRTCRAM								;Write data from A to RTC memory location X
.LA7C0      CLC
            RTS

.LA7C2      LDX #&0B								;Select 'Register B' register on RTC: Register &0B
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            AND #&08
            BNE LA7C0
            SEC
            RTS

.LA7CD      LDA prvOswordBlockCopy + 9
            CMP #&00
            BNE LA7D7
            LDA prvOswordBlockCopy + 8
.LA7D7      LSR A
            BCS LA7C0
            LSR A
            BCS LA7C0
            SEC
            RTS

.LA7DF      DEY
            LDA LA7F2,Y
            INY
            CPY #&02
            BNE LA7F1
            PHA
            JSR LA7CD
            PLA
            BCC LA7F1
            LDA #&1D
.LA7F1      RTS

;Lookup table for Number of Days in each month
.LA7F2		EQUB &1F								;January:		31 days
		EQUB &1C								;February:	28 days
		EQUB &1F								;March:		31 days
		EQUB &1E								;April:		30 days
		EQUB &1F								;May:		31 days
		EQUB &1E								;June:		30 days
		EQUB &1F								;July:		31 days
		EQUB &1F								;August:		31 days
		EQUB &1E								;September:	30 days
		EQUB &1F								;October:		31 days
		EQUB &1E								;November:	30 days
		EQUB &1F								;December:	31 days

.LA7FE      LDA #&00
            STA prvOswordBlockCopy + 4
            STA prvOswordBlockCopy + 5
            LDY #&00
.LA808      INY
            CPY prvOswordBlockCopy + 10
            BEQ LA823
            JSR LA7DF
            CLC
            ADC prvOswordBlockCopy + 4
            STA prvOswordBlockCopy + 4
            LDA prvOswordBlockCopy + 5
            ADC #&00
            STA prvOswordBlockCopy + 5
            BCC LA808
            RTS

.LA823      LDX prvOswordBlockCopy + 11
            DEX
            TYA
            CLC
            ADC prvOswordBlockCopy + 4
            STA prvOswordBlockCopy + 4
            LDA prvOswordBlockCopy + 5
            ADC #&00
            STA prvOswordBlockCopy + 5
            RTS

.LA838      CLC
            BCC LA83C
.LA83B      SEC
.LA83C      PHP
            LDA prvOswordBlockCopy + 8
            LDX #&00
            LDY #&63
            JSR LA8DB
            LDA #&80
            JSR LA8C9
            LDA prvOswordBlockCopy + 9
            LDX #&00
            LDY #&63
            JSR LA8DB
            LDA #&40
            JSR LA8C9
            LDA prvOswordBlockCopy + 10
            LDX #&01
            LDY #&0C
            JSR LA8DB
            LDA #&20
            JSR LA8C9
            PLP
            BCC LA880
            LDA prvOswordBlockCopy + 10
            CMP #&FF
            BNE LA878
            LDY #&1F
            BNE LA887
.LA878      CMP #&02
            BNE LA880
            LDY #&1D
            BNE LA887
.LA880      LDY prvOswordBlockCopy + 10
            JSR LA7DF
            TAY
.LA887      LDA prvOswordBlockCopy + 11
            LDX #&01
            JSR LA8DB
            LDA #&10
            JSR LA8C9
            LDA prvOswordBlockCopy + 12
            LDX #&00
            LDY #&07
            JSR LA8DB
            LDA #&08
            JSR LA8C9
            LDA prvOswordBlockCopy + 13
            LDX #&00
            LDY #&17
            JSR LA8DB
            LDA #&04
            JSR LA8C9
            LDA prvOswordBlockCopy + 14
            LDX #&00
            LDY #&3B
            JSR LA8DB
            LDA #&02
            JSR LA8C9
            LDA prvOswordBlockCopy + 15
            JSR LA8DB
            LDA #&01
.LA8C9      BCC LA8D2
            ORA prvOswordBlockCopy
            STA prvOswordBlockCopy
            RTS

.LA8D2      EOR #&FF
            AND prvOswordBlockCopy
            STA prvOswordBlockCopy
            RTS

.LA8DB      STA prv82+&4E
            CPY prv82+&4E
            BCC LA8ED
            STX prv82+&4E
            CMP prv82+&4E
            BCC LA8ED
            CLC
            RTS
			
.LA8ED      SEC
            RTS

            LDA prvOswordBlockCopy + 13
            BPL LA904
            CMP #&8C
            BNE LA8FC
            LDA #&00
            BEQ LA901
.LA8FC      AND #&7F
            CLC
            ADC #&0C
.LA901      STA prvOswordBlockCopy + 13
.LA904      RTS

.LA905      CLC
            BCC LA909
.LA908      SEC
.LA909      PHP
            LDA prvOswordBlockCopy + 9
            STA prv82+&4F
            LDA prvOswordBlockCopy + 8
            STA prv82+&4E
            SEC
            LDA prvOswordBlockCopy + 10
            SBC #&02
            STA prv82+&50
            BMI LA925
            CMP #&01
            BCS LA947
.LA925      CLC
            ADC #&0C
            STA prv82+&50
            DEC prv82+&4F
            BPL LA947
            CLC
            LDA prv82+&4F
            ADC #&64
            STA prv82+&4F
            DEC prv82+&4E
            BPL LA947
            CLC
            LDA prv82+&4E
            ADC #&64
            STA prv82+&4E
.LA947      LDA prv82+&50
            STA prv82+&4A
            LDA #&82
            STA prv82+&4B
            JSR LA604
            ASL prv82+&4C
            ROL prv82+&4D
            SEC
            LDA prv82+&4C
            SBC #&13
            STA prv82+&4A
            LDA prv82+&4D
            SBC #&00
            STA prv82+&4B
            LDA #&64
            STA prv82+&4C
            JSR LA624
            CLC
            LDA prv82+&4D
            ADC prvOswordBlockCopy + 11
            ADC prv82+&4F
.LA97E      STA prv82+&4A
            LDA prv82+&4F
            LSR A
            LSR A
            CLC
            ADC prv82+&4A
            STA prv82+&4A
            LDA prv82+&4E
            LSR A
            LSR A
            CLC
            ADC prv82+&4A
            ASL prv82+&4E
            SEC
            SBC prv82+&4E
            PHP
            BCS LA9A5
            SEC
            SBC #&01
            EOR #&FF
.LA9A5      STA prv82+&4A
            LDA #&00
            STA prv82+&4B
            LDA #&07
            STA prv82+&4C
            JSR LA624
            PLP
            BCS LA9C0
            SEC
            SBC #&01
            EOR #&FF
            CLC
            ADC #&07
.LA9C0      CMP #&07
            BCC LA9C6
            SBC #&07
.LA9C6      STA prv82+&4A
            INC prv82+&4A
            LDA prv82+&4A
            PLP
            BCS LA9E5
            CMP prvOswordBlockCopy + 12
            BEQ LA9DF
            LDA #&08
            ORA prvOswordBlockCopy
            STA prvOswordBlockCopy
.LA9DF      LDA prv82+&4A
            STA prvOswordBlockCopy + 12
.LA9E5      RTS

.LA9E6      LDA #&01
            STA prvOswordBlockCopy + 11
            JSR LA905
            LDY prvOswordBlockCopy + 10
            JSR LA7DF
            STA L00AA
.LA9F6      CLC
            LDA L00AA
            ADC prvOswordBlockCopy + 12
            CMP #&25
            BCS LAA0C
            CLC
            LDA prvOswordBlockCopy + 12
            ADC #&07
            STA prvOswordBlockCopy + 12
            JMP LA9F6
			
.LAA0C      LDA prvOswordBlockCopy + 4
            STA L00AB
            LDA prvOswordBlockCopy + 5
            STA L00AC
            LDA #&00
            LDY #&2A
.LAA1A      DEY
            STA (L00AB),Y
            BNE LAA1A
            INC L00AA
.LAA21      LDA prvOswordBlockCopy + 11
            CMP L00AA
            BCC LAA29
            RTS

.LAA29      ADC prvOswordBlockCopy + 12
            SEC
            SBC #&02
            STA prv82+&4A
            LDA #&00
            STA prv82+&4B
            LDA #&07
            STA prv82+&4C
            JSR LA624
            STA prv82+&4A
            LDA #&06
            STA prv82+&4B
            LDA prv82+&4D
            PHA
            JSR LA604
            PLA
            CLC
            ADC prv82+&4C
            TAY
            LDA prvOswordBlockCopy + 11
            STA (L00AB),Y
            INC prvOswordBlockCopy + 11
            JMP LAA21

;Calendar text (LAA5F)
.calText		EQUS "today"
		EQUS "sunday"
		EQUS "monday"
		EQUS "tuesday"
		EQUS "wednesday"
		EQUS "thursday"
		EQUS "friday"
		EQUS "saturday"
		EQUS "january"
		EQUS "february"
		EQUS "march"
		EQUS "april"
		EQUS "may"
		EQUS "june"
		EQUS "july"
		EQUS "august"
		EQUS "september"
		EQUS "october"
		EQUS "november"
		EQUS "december"
	
;Calendar text offset (LAAE0)
.calOffset	EQUB &00,&05,&0B,&11,&18,&21,&29,&2F
		EQUB &37,&3E,&46,&4B,&50,&53,&57,&5B
		EQUB &61,&6A,&71,&79,&81


;&824E=calText pointer for next month / day
;&824F=Capitalisation mask (&DF or &FF)			
;&8250=calOffset pointer
;On Month Entry:		Carry Set,   A=01-12 (Jan-Dec)
;On Day of Week Entry:	Carry Clear, A=01-07 (Sun-Sat)		
.LAAF5	  BCC LAAFA								;If Carry clear then jump to Day of Week
	  CLC
            ADC #&07								;move calOffset pointer to first month
.LAAFA      STX prv82+&50								;save calOffset pointer to &8250
            CPY #&00								;First letter?
            BNE LAB09								;No? Then branch
            LDY #&DF								;Load capitalise mask
            STY prv82+&4F								;Save mask to &824F
            JMP LAB0E
			
.LAB09      LDY #&FF								;otherwise no capitalise
            STY prv82+&4F								;save mask to &824F
.LAB0E      TAX
            INX
            LDA calOffset,X								;get calText pointer for next month / day
            STA prv82+&4E								;save calText pointer for next month / day to &824E
            DEX
            LDA calOffset,X								;get calText pointer for current month / day
            TAX									;move calText pointer for current month / day to X
            LDY L00AA								;get buffer pointer
            LDA calText,X								;get first letter
            AND #&DF								;capitalise this letter
            JMP LAB2B
			
.LAB25      LDA calText,X								;get subsequent letters
            AND prv82+&4F								;apply capitalisation mask
.LAB2B      STA (L00A8),Y								;store at buffer &XY?Y
            INY									;increase buffer pointer
            INX									;increment calText pointer for current month / day
            DEC prv82+&50								;***why reduce this pointer?***
            BEQ LAB39
            CPX prv82+&4E								;reached the calText pointer for next month / day?
            BNE LAB25								;no? loop.
.LAB39      STY L00AA								;save buffer pointer
            RTS
			
;Split number in register A into 10s and 1s, characterise and store units in &824F and 10s in &824E
;convert to characters, store in buffer XY?Y, increase buffer pointer, save buffer pointer and return
.LAB3C      JSR LABAB								;Split number in register A into 10s and 1s, characterise and store units in &824F and 10s in &824E
            LDY L00AA								;get buffer pointer
.LAB41      CPX #&00
            BEQ LAB65
            LDA prv82+&4E								;get 10s
            CMP #&30								;is it '0'
            BNE LAB65
            CPX #&01	
            BEQ LAB6B
            LDA #&20								;convert '0' to ' '
            STA prv82+&4E								;and save to &824E
            LDA prv82+&4F								;get 1s
            CMP #&30								;is it '0'
            BNE LAB65
            CPX #&03
            BNE LAB65
            LDA #&20								;convert '0' to ' '
            STA prv82+&4F								;and save to &824F
.LAB65      LDA prv82+&4E								;get 10s
            STA (L00A8),Y								;store at buffer &XY?Y
            INY									;increase buffer pointer
.LAB6B      LDA prv82+&4F								;get 1s
            JMP LABE4								;store at buffer &XY?Y, increase buffer pointer, save buffer pointer and return.
			
;postfix for dates. eg 25th, 1st, 2nd, 3rd
.LAB71		EQUS "th", "st", "nd", "rd"
	
.LAB79      PHP									;save carry flag. Used to select capitalisation
            JSR LABAB								;Split number in register A into 10s and 1s, characterise and store units in &824F and 10s in &824E
            LDA prv82+&4E								;get 10s
            CMP #&31								;check for '1'
            BNE LAB89								;branch if not 1.
.LAB84      LDX #&00								;if the number is in 10s, then always 'th'
            JMP LAB94
			
.LAB89      LDA prv82+&4F								;get 1s
            CMP #&34								;check if '4'
            BCS LAB84								;branch if >='4'
            AND #&0F								;mask lower 4 bits
            ASL A									;x2 - 1 becomes 2, 2 becomes 4, 3 becomes 6
            TAX
.LAB94      PLP									;restore carry flag. Used to select capitalisation
            LDY L00AA								;get buffer pointer
            LDA LAB71,X								;get 1st character from table + offset
            BCC LAB9E								;don't capitalise
            AND #&DF								;capitalise
.LAB9E      STA (L00A8),Y								;store at buffer &XY?Y
            INY									;increase buffer pointer
            LDA LAB71+1,X								;get 2nd character from table + offset
            BCC LABA8								;don't capitalise
            AND #&DF								;capitalise
.LABA8      JMP LABE4								;store at buffer &XY?Y, increase buffer pointer, save buffer pointer and return

;Split number in register A into 10s and 1s, characterise and store 1s in &824F and 10s in &824E 
.LABAB      LDY #&FF							
            SEC
.LABAE      INY									;starting at 0
            SBC #&0A
            BCS LABAE								;count 10s till negative. Total 10s stored in Y
            ADC #&0A								;restore last subtract to get positive again. This gets the units
            ORA #&30								;convert units to character
            STA prv82+&4F								;save units to &824F
            TYA									;get 10s
            ORA #&30								;convert 10s to character
            STA prv82+&4E								;save 10s to &824F
            RTS
			
.LABC1		EQUS "am", "pm"

.LABC5      TAX
            CPX #&00								;is it 00 hrs?
            BNE LABCC								;branch if not 00 hrs
            LDX #&18								;else set X=24 (hrs)
.LABCC      LDA #&00
            CPX #&0D								;carry set if X>=13 (hrs) ('pm')
            ADC #&00								;otherwise ('am')
            ASL A									;x2 - A=0 ('am') or A=2 ('pm')
            TAX
            LDY L00AA								;get buffer pointer
            LDA LABC1,X								;get 'a' or 'p'
            STA (L00A8),Y								;save contents of A to Buffer Address+Y
            INY									;increase buffer pointer
            LDA LABC1+1,X								;get 'm'
            JMP LABE4								;store at buffer &XY?Y, increase buffer pointer, save buffer pointer and return
			
;&AA stores the buffer address offset
;&00A8 stores the address of buffer address
;this code saves the contents of A to buffer address + buffer address offset
.LABE2      LDY L00AA								;read buffer pointer
.LABE4      STA (L00A8),Y								;save contents of A to Buffer Address+Y
            INY									;increase buffer pointer
            STY L00AA								;save buffer pointer
            RTS
			
.LABEA      LDA prvOswordBlockCopy + 2								;&44 for OSWORD 0E
            AND #&0F								;&04 for OSWORD 0E
            STA L00AB
            BNE LABF5
            SEC
            RTS
			
.LABF5      LDA L00AB
            CMP #&04
            BCC LAC27								;branch if <4
            LDX #&00
            AND #&02
            EOR #&02
            BNE LAC05
            INX
            INX
.LAC05      LDA L00AB
            AND #&01
            PHP
            LDA prvOswordBlockCopy + 13								;read Hours
            PLP
            BEQ LAC1F
            LDA prvOswordBlockCopy + 13								;read Hours
            BEQ LAC1D								;check for 00hrs. If so, convert to 12
            CMP #&0D								;
            BCC LAC1F								;check for 13hrs and above
            SBC #&0C								;if so, subtract 12
            BCS LAC1F
.LAC1D      LDA #&0C								;get '0C'
.LAC1F      JSR LAB3C								;convert to characters, store in buffer XY?Y, increase buffer pointer, save buffer pointer and return
            LDA #':'								;':'
            JSR LABE2								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
.LAC27      LDX #&00
            LDA L00AB
            CMP #&04
            BCS LAC34								;branch if >=4
            CMP #&01
            BEQ LAC34								;branch if =1
            TAX
.LAC34      LDA prvOswordBlockCopy + 14								;read Minutes
            JSR LAB3C								;convert to characters, store in buffer XY?Y, increase buffer pointer, save buffer pointer and return
            LDA L00AB
            CMP #&08
            BCC LAC48
            CMP #&0C
            BCC LAC55
            LDA #&2F								;'/'
            BNE LAC4A
.LAC48      LDA #&3A								;':'
.LAC4A      JSR LABE2								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
            LDX #&00
            LDA prvOswordBlockCopy + 15								;read seconds
            JSR LAB3C								;convert to characters, store in buffer XY?Y, increase buffer pointer, save buffer pointer and return
.LAC55      LDA L00AB
            CMP #&04
            BCC LAC6C
            LDA L00AB
            AND #&01
            BEQ LAC6C
            LDA #&20								;' '
            JSR LABE2								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
            LDA prvOswordBlockCopy + 13								;read hours
            JSR LABC5								;write am / pm to 
.LAC6C      CLC
            RTS
			
;Separators for Time Display? 
.LAC6E		EQUS " ", "/", ".", "-"
	
.LAC72		LDA prvOswordBlockCopy + 2
            LSR A
            LSR A
            LSR A
            LSR A
            STA L00AB
            BEQ LACBB
            AND #&01
            EOR #&01
            TAY
            LDA L00AB
            LDX #&00
            CMP #&05
            BCS LAC91
            LDX #&03
            CMP #&03
            BCS LAC91
            DEX
.LAC91      LDA prvOswordBlockCopy + 12								;get day of week
            CLC									;Carry Set=Month, Clear=Day of Week
            JSR LAAF5								;Save Day of Week text to buffer XY?xxx
            LDA prvOswordBlockCopy + 3
            BNE LACA0
            JMP LAD5A
			
.LACA0      LDA prvOswordBlockCopy + 1
            AND #&0F
            STA L00AB
            CMP #&04
            BCC LACB6
            LDA #&2C								;','
            JSR LABE2								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
            LDA L00AB
            CMP #&08
            BCC LACBB
.LACB6      LDA #&20								;' '
            JSR LABE2								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
.LACBB      LDA prvOswordBlockCopy + 3
            AND #&07
            STA L00AB
            BEQ LACF8
            LDX #&01
            CMP #&04
            BCS LACD0
            DEX
            CMP #&03
            BEQ LACD0
            TAX
.LACD0      LDA prvOswordBlockCopy + 11								;read Day of Month
            JSR LAB3C								;convert to characters, store in buffer XY?Y, increase buffer pointer, save buffer pointer and return
            LDA L00AB
            CMP #&04
            BCC LACE5
            BEQ LACDF
            CLC									;don't capitalise
.LACDF      LDA prvOswordBlockCopy + 11;								;Get Day of Month from RTC
            JSR LAB79								;Convert to text, then save to buffer XY?Y, increment buffer address offset.
.LACE5      LDA prvOswordBlockCopy + 3
            AND #&F8
            BEQ LAD5A
            LDA prvOswordBlockCopy + 1
            AND #&03								;mask lower 3 bits
            TAX
            LDA LAC6E,X								;get character from look up table
            JSR LABE2								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
.LACF8      LDA prvOswordBlockCopy + 3
            LSR A
            LSR A
            LSR A
            AND #&07
            STA L00AB
            BEQ LAD3D
            CMP #&04
            BCS LAD18
            LDX #&00
            CMP #&03
            BEQ LAD0F
            TAX
.LAD0F      LDA prvOswordBlockCopy + 10								;read month
            JSR LAB3C								;convert to characters, store in buffer XY?Y, increase buffer pointer, save buffer pointer and return
            JMP LAD2A
			
.LAD18      LDX #&03
            CMP #&06
            BCC LAD20
            LDX #&00
.LAD20      AND #&01
            TAY
            LDA prvOswordBlockCopy + 10								;Get Month
            SEC									;Carry Set=Month, Clear=Day of Week
            JSR LAAF5								;Save Month text to buffer XY?xxx
.LAD2A      LDA prvOswordBlockCopy + 3
            AND #&C0
            BEQ LAD5A
            LDA prvOswordBlockCopy + 1
            AND #&03								;mask lower 3 bits
            TAX
            LDA LAC6E,X								;get character from look up table
            JSR LABE2								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
.LAD3D      LDA prvOswordBlockCopy + 3
            AND #&C0
            BEQ LAD5A
            CMP #&80
            BCC LAD52
            BEQ LAD5B
            LDX #&00
            LDA prvOswordBlockCopy + 8								;read century
            JSR LAB3C								;convert to characters, store in buffer XY?Y, increase buffer pointer, save buffer pointer and return
.LAD52      LDX #&00
            LDA prvOswordBlockCopy + 9								;read year
            JMP LAB3C								;convert to characters, store in buffer XY?Y, increase buffer pointer, save buffer pointer and return
			
.LAD5A      RTS

.LAD5B      LDA #&27								;'''
            JSR LABE2								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
            JMP LAD52
			

;read buffer address from &8224 and store at &A8
;set buffer pointer to 0
.LAD63      LDA prvOswordBlockCopy + 4								;get OSWORD X register (lookup table LSB)
            STA L00A8								;and save
            LDA prvOswordBlockCopy + 5								;get OSWORD Y register (lookup table MSB)
            STA L00A9								;and save
            LDA #&00
            STA L00AA								;set buffer pointer to 0
            JSR LAD7F
            LDA #&0D
            JSR LABE2								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
            LDY L00AA								;get buffer pointer
            STY prvOswordBlockCopy + 1
.LAD7E      RTS

.LAD7F      BIT prvOswordBlockCopy + 1							;
            BMI LAD8D								;do the reverse of below
            JSR LABEA
            JSR LAD96
            JMP LAC72
			
.LAD8D      JSR LAC72
            JSR LAD96
            JMP LABEA
			
.LAD96      LDA prvOswordBlockCopy + 1
            AND #&F0
            CMP #&D0
            BEQ LADBE
            STA L00AB
            AND #&40
            BNE LADB9
.LADA5      LDA L00AB
            LDX #&2C
            AND #&20
            BNE LADAF
            LDX #&2E
.LADAF      TXA
            JSR LABE2								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
            LDA L00AB
            AND #&10
            BEQ LAD7E
.LADB9      LDA #&20								;' '
            JMP LABE2								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
			
.LADBE      LDA #&20								;' '
            JSR LABE2								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
            LDA #&40								;'@'
            JSR LABE2								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
            JMP LADB9
			
.LADCB      LDA #&00
            STA prvOswordBlockCopy
            SEC
            LDA prvOswordBlockCopy + 8
            SBC #&13
            BCC LAE26
            BEQ LADE0
            CMP #&01
            BNE LAE26
            LDA #&64
.LADE0      CLC
            ADC prvOswordBlockCopy + 9
            PHA
            STA prv82+&4A
            LDA #&6D
            STA prv82+&4B
            JSR LA604
            CLC
            PLA
            PHA
            ADC prv82+&4D
            STA prv82+&4D
            PLA
            LSR A
            LSR A
            CLC
            ADC prv82+&4C
            STA prv82+&4C
            LDA prv82+&4D
            ADC #&00
            STA prv82+&4D
            BCS LAE26
            JSR LA7FE
            CLC
            LDA prvOswordBlockCopy + 4
            ADC prv82+&4C
            STA prvOswordBlockCopy + 4
            LDA prvOswordBlockCopy + 5
            ADC prv82+&4D
            STA prvOswordBlockCopy + 5
            BCS LAE26
            RTS
			
.LAE26      LDA #&FF
            STA prvOswordBlockCopy
            RTS
			
.LAE2C      LDA #&13
            STA prvOswordBlockCopy + 8
            SEC
            LDA prvOswordBlockCopy + 4
            SBC #&AC
            STA prv82+&4A
            LDA prvOswordBlockCopy + 5
            SBC #&8E
            BCC LAE4D
            STA prvOswordBlockCopy + 5
            LDA prv82+&4A
            STA prvOswordBlockCopy + 4
            INC prvOswordBlockCopy + 8
.LAE4D      LDA #&00
            STA prvOswordBlockCopy + 9
.LAE52      JSR LA7CD
            LDA #&6D
            ADC #&00
            STA prv82+&4A
            LDA #&01
            STA prv82+&4B
            SEC
            LDA prvOswordBlockCopy + 4
            SBC prv82+&4A
            STA prv82+&4A
            LDA prvOswordBlockCopy + 5
            SBC prv82+&4B
            BCC LAE82
            STA prvOswordBlockCopy + 5
            LDA prv82+&4A
            STA prvOswordBlockCopy + 4
            INC prvOswordBlockCopy + 9
            JMP LAE52
			
.LAE82      LDA #&01
            STA prvOswordBlockCopy + 10
.LAE87      LDY prvOswordBlockCopy + 10
            JSR LA7DF
            STA prv82+&4A
            SEC
            LDA prvOswordBlockCopy + 4
            SBC prv82+&4A
            STA prv82+&4A
            LDA prvOswordBlockCopy + 5
            SBC #&00
            BCC LAEB0
            STA prvOswordBlockCopy + 5
            LDA prv82+&4A
            STA prvOswordBlockCopy + 4
            INC prvOswordBlockCopy + 10
            JMP LAE87
			
.LAEB0      LDX prvOswordBlockCopy + 4
            INX
            STX prvOswordBlockCopy + 11
            JMP LA905
			
.LAEBA      CLC
            LDA prvOswordBlockCopy + 11
            ADC #&07
            STA prvOswordBlockCopy + 11
            LDY prvOswordBlockCopy + 10
            JSR LA7DF
            CMP prvOswordBlockCopy + 11
            BCS LAF3C
            STA prv82+&4E
            SEC
            LDA prvOswordBlockCopy + 11
            SBC prv82+&4E
            STA prvOswordBlockCopy + 11
            JMP LAEF8
			
.LAEDE      LDA #&02
            BIT prv82+&42
            BEQ LAEF8
            INC prvOswordBlockCopy + 11
            LDY prvOswordBlockCopy + 10
            JSR LA7DF
            CMP prvOswordBlockCopy + 11
            BCS LAF3C
            LDA #&01
            STA prvOswordBlockCopy + 11
.LAEF8      LDA #&04
            BIT prv82+&42
            BEQ LAF0E
            INC prvOswordBlockCopy + 10
            LDA prvOswordBlockCopy + 10
            CMP #&0D
            BCC LAF3C
            LDA #&01
            STA prvOswordBlockCopy + 10
.LAF0E      LDA #&08
            BIT prv82+&42
            BEQ LAF24
            INC prvOswordBlockCopy + 9
            LDA prvOswordBlockCopy + 9
            CMP #&64
            BCC LAF3F
            LDA #&00
            STA prvOswordBlockCopy + 9
.LAF24      LDA #&10
            BIT prv82+&42
            BEQ LAF3F
            INC prvOswordBlockCopy + 8
            LDA prvOswordBlockCopy + 8
            CMP #&64
            BCC LAF3F
            LDA #&00
            STA prvOswordBlockCopy + 8
            SEC
            RTS
			
.LAF3C      CLV
            CLC
            RTS
			
.LAF3F      BIT LAF43
            CLC
.LAF43      RTS

.LAF44      DEC prvOswordBlockCopy + 11
            BNE LAF3C
            LDY prvOswordBlockCopy + 10
            DEY
            BNE LAF51
            LDY #&0C
.LAF51      JSR LA7DF
            STA prvOswordBlockCopy + 11
            STY prvOswordBlockCopy + 10
            CPY #&0C
            BCC LAF3C
            DEC prvOswordBlockCopy + 9
            LDA prvOswordBlockCopy + 9
            CMP #&FF
            BNE LAF3F
            LDA #&63
            STA prvOswordBlockCopy + 9
            DEC prvOswordBlockCopy + 8
            LDA prvOswordBlockCopy + 8
            CMP #&FF
            BNE LAF3F
            SEC
            RTS
			
.LAF79      LDA prv82+&42
            AND #&08
            BNE LAFAA
            LDA prv82+&42
            AND #&10
            BEQ LAF94
            LDA #&13
            STA prvOswordBlockCopy + 8
            LDA prv82+&42
            AND #&0F
            STA prv82+&42
.LAF94      LDX #&00
.LAF96      LDA prvOswordBlockCopy + 8,X
            CMP #&FF
            BNE LAF9F
            TXA
            LSR A
.LAF9F      STA prvOswordBlockCopy + 8,X
            INX
            CPX #&04
            BNE LAF96
            JMP LAFEC
			
.LAFAA      JSR LA70F
            LDA prv82+&42
            AND #&1E
            CMP #&1E
            BEQ LAFEC
            LDA prv82+&42
            STA prv82+&48
            LDA #&1E
            STA prv82+&42
.LAFC1      LDA prv82+&46
            CMP #&FF
            BEQ LAFCD
            CMP prvOswordBlockCopy + 11
            BNE LAFD9
.LAFCD      LDA prv82+&45
            CMP #&FF
            BEQ LAFE6
            CMP prvOswordBlockCopy + 10
            BEQ LAFE6
.LAFD9      JSR LAEDE
            BCC LAFC1
            LDA prv82+&48
            STA prv82+&42
            SEC
            RTS
			
.LAFE6      LDA prv82+&48
            STA prv82+&42
.LAFEC      JSR LA908
            STA prvOswordBlockCopy + 12
            LDA #&00
            STA prvOswordBlockCopy
            CLC
            RTS

{
.^LAFF9      LDX #&04
.LAFFB      LDA prvOswordBlockCopy + 8,X
            STA prv82+&43,X
            DEX
            BPL LAFFB
            LDX #&00
            STX prv82+&42
.LB009      LDA prvOswordBlockCopy + 8,X
            CMP #&FF
            ROL prv82+&42
            INX
            CPX #&05
            BNE LB009
            JSR LAF79
            BCS LB02E
            LDA prv82+&47
            CMP #&FF
            BNE LB033
            JSR LA838
            LDA prvOswordBlockCopy
            AND #&F0
            BNE LB02E
            CLC
            RTS
}
			
.LB02E      BIT LB032
            SEC
.LB032      RTS

.LB033      CMP #&07
            BCC LB03E
            CMP #&5B
            BCC LB086
            JMP LB0F3
			
.LB03E      LDA prv82+&42
            AND #&0E
            BNE LB04F
            JSR LA838
            LDA prvOswordBlockCopy
            AND #&F0
            BNE LB07E
.LB04F      INC prv82+&47
.LB052      LDA prv82+&47
            CMP prvOswordBlockCopy + 12
            BEQ LB071
.LB05A      JSR LAEDE
            BCS LB07E
            BVC LB068
            LDA #&08
            BIT prv82+&42
            BEQ LB083
.LB068      JSR LA908
            STA prvOswordBlockCopy + 12
            JMP LB052
			
.LB071      JSR LA838
            LDA prvOswordBlockCopy
            AND #&F0
            BNE LB05A
.LB07B      CLV
            CLC
            RTS
			
.LB07E      SEC
            BIT LB082
.LB082      RTS

.LB083      CLV
            SEC
            RTS
			
.LB086      STA prv82+&4A
            LDA #&00
            STA prv82+&4B
            LDA #&07
            STA prv82+&4C
            JSR LA624
            TAX
            INX
            STX prvOswordBlockCopy + 12
            LDA #&1E
            STA prv82+&42
            LDX prv82+&4D
            CPX #&0A
            BEQ LB0E7
            CPX #&0B
            BEQ LB0CD
            CPX #&0C
            BEQ LB0DA
            TXA
            PHA
.LB0B1      JSR LA908
            CMP prvOswordBlockCopy + 12
            BEQ LB0C1
            JSR LAEDE
            BCC LB0B1
            PLA
            BCS LB07E
.LB0C1      PLA
            TAX
.LB0C3      DEX
            BEQ LB07B
            JSR LAEBA
            BCC LB0C3
            CLV
            RTS
			
.LB0CD      JSR LAEDE
            JSR LA908
            CMP prvOswordBlockCopy + 12
            BNE LB0CD
            BEQ LB07B
.LB0DA      JSR LAF44
            JSR LA908
            CMP prvOswordBlockCopy + 12
            BNE LB0DA
            BEQ LB07B
.LB0E7      JSR LA908
            CMP prvOswordBlockCopy + 12
            BEQ LB07B
            BCS LB0DA
            BCC LB0CD
.LB0F3      LDA #&1E
            STA prv82+&42
            LDA prv82+&47
            CMP #&9B
            BCC LB116
            SBC #&9A
            TAX
.LB102      JSR LAEDE
            BCC LB10A
            JMP LB07E
			
.LB10A      DEX
            BNE LB102
            JSR LA908
            STA prvOswordBlockCopy + 12
            JMP LB07B
			
.LB116      SEC
            SBC #&5A
            TAX
.LB11A      JSR LAF44
            BCC LB122
            JMP LB07E
			
.LB122      DEX
            BNE LB11A
            JSR LA908
            STA prvOswordBlockCopy + 12
            JMP LB07B
			
.LB12E      SEC
            BIT LB132
.LB132      RTS

.LB133      LDX #&04
            LDA #&FF
.LB137      STA prvOswordBlockCopy + 8,X
            DEX
            BPL LB137
            JSR findNextCharAfterSpace								;find next character. offset stored in Y
            LDA (L00A8),Y
            CMP #&0D
            BEQ LB197
            JSR LB1ED
            BCS LB12E
            STA prvOswordBlockCopy + 12
            CMP #&FF
            BEQ LB15C
            JSR findNextCharAfterSpace								;find next character. offset stored in Y
            LDA (L00A8),Y
            CMP #&2C
            BNE LB197
            INY
.LB15C      JSR convertIntegerDefaultDecimal
            BCC LB163
            LDA #&FF
.LB163      STA prvOswordBlockCopy + 11
            JSR findNextCharAfterSpace								;find next character. offset stored in Y
            LDA (L00A8),Y
            CMP #&2F
            BNE LB197
            INY
            JSR convertIntegerDefaultDecimal
            BCC LB177
            LDA #&FF
.LB177      STA prvOswordBlockCopy + 10
            JSR findNextCharAfterSpace								;find next character. offset stored in Y
            LDA (L00A8),Y
            CMP #&2F
            BNE LB197
            INY
            JSR convertIntegerDefaultDecimal
            BCC LB194
            LDA #&FF
            STA prvOswordBlockCopy + 9
            STA prvOswordBlockCopy + 8
            JMP LB197
			
.LB194      JSR LB1CA
.LB197      JSR LA83B
            LDA prvOswordBlockCopy
            LSR A
            LSR A
            LSR A
            LSR A
            PHA
            LDX #&00
            STX prvOswordBlockCopy
.LB1A7      LDA prvOswordBlockCopy + 8,X
            CMP #&FF
            ROL prvOswordBlockCopy
            INX
            CPX #&04
            BNE LB1A7
            LDA prvOswordBlockCopy
            EOR #&0F
            STA prvOswordBlockCopy
            PLA
            AND prvOswordBlockCopy
            AND #&0F
            BNE LB1C7
            JMP LAFF9
			
.LB1C7      JMP LB12E

.LB1CA      LDA L00B0
            STA prv82+&4A
            LDA L00B1
            STA prv82+&4B
            LDA #&64
            STA prv82+&4C
            JSR LA624
            STA prvOswordBlockCopy + 9
            LDA prv82+&4D
            BNE LB1E9
.LB1E4      LDX #&35
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
.LB1E9      STA prvOswordBlockCopy + 8
            RTS
			
.LB1ED      STY prv82+&4E
            LDA #&00
            STA L00AB
            JSR findNextCharAfterSpace								;find next character. offset stored in Y
            LDA (L00A8),Y
            CMP #&2B
            BEQ LB215
            CMP #&2D
            BNE LB22D
            INY
            JSR convertIntegerDefaultDecimal
            BCS LB20B
            CMP #&00
            BNE LB20D
.LB20B      LDA #&01
.LB20D      CMP #&41
            BCS LB229
            ADC #&5A
            CLC
            RTS
			
.LB215      INY
            JSR convertIntegerDefaultDecimal
            BCS LB21F
            CMP #&00
            BNE LB221
.LB21F      LDA #&01
.LB221      CMP #&65
            BCS LB229
            ADC #&9A
            CLC
            RTS
			
.LB229      LDA #&FF
            SEC
            RTS
			
.LB22D      LDX #&00
.LB22F      STX prv82+&50
            LDA calOffset+1,X
            STA L00AA
            LDA calOffset,X
            STA prv82+&4F
            TAX
.LB23E      LDA (L00A8),Y
            ORA #&20
            CMP calText,X
            BNE LB24F
            INY
            INX
            CPX L00AA
            BEQ LB26A
            BNE LB23E
.LB24F      SEC
            TXA
            SBC prv82+&4F
            CMP #&02
            BCS LB26A
            LDY prv82+&4E
            LDX prv82+&50
            INX
            CPX #&08
            BCC LB22F
            LDY prv82+&4E
            LDA #&FF
            CLC
            RTS
			
.LB26A      LDA prv82+&50
            BNE LB27B
            LDX #&06								;Select 'Day of Week' register on RTC: Register &06
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            STA prv82+&50
            LDA #&FF
            STA L00AB
.LB27B      LDX #&00
            LDA (L00A8),Y
            CMP #&2B								;'+'
            BNE LB285
            LDX #&0B
.LB285      CMP #'-'
            BNE LB28B
            LDX #&0C
.LB28B      CMP #'*'
            BNE LB291
            LDX #&0A
.LB291      CMP #'1'
            BCC LB29C
            CMP #'9'+1								;':' Between 0..9 SFTODO: between 1..9?
            BCS LB29C
            AND #&0F
            TAX
.LB29C      CPX #&00
            BEQ LB2A1
            INY
.LB2A1      DEC prv82+&50
            STX prv82+&51
            TXA
            ASL A
            ASL A
            ASL A
            SEC
            SBC prv82+&51
            CLC
            ADC prv82+&50
            CLC
            RTS
			
.LB2B5      JSR convertIntegerDefaultDecimal
            BCS LB2F3
            STA prvOswordBlockCopy + 13
            LDA (L00A8),Y
            INY
            CMP #&3A
            BNE LB2F3
            JSR convertIntegerDefaultDecimal
            BCS LB2F3
            STA prvOswordBlockCopy + 14
            LDA (L00A8),Y
            CMP #&3A
            BEQ LB2DA
            CMP #&2F
            BEQ LB2DA
            LDA #&00
            BEQ LB2E0
.LB2DA      INY
            JSR convertIntegerDefaultDecimal
            BCS LB2F3
.LB2E0      STA prvOswordBlockCopy + 15
            TYA
            PHA
            JSR LA83B
            PLA
            TAY
            LDA prvOswordBlockCopy
            AND #&07
            BNE LB2F3
            CLC
            RTS
			
.LB2F3      SEC
            RTS
			
.LB2F5      LDA #&00
            STA prvOswordBlockCopy + 12
            JSR convertIntegerDefaultDecimal
            BCS LB32F
            STA prvOswordBlockCopy + 11
            LDA (L00A8),Y
            INY
            CMP #&2F
            BNE LB32F
            JSR convertIntegerDefaultDecimal
            BCS LB32F
            STA prvOswordBlockCopy + 10
            LDA (L00A8),Y
            INY
            CMP #&2F
            BNE LB32F
            JSR convertIntegerDefaultDecimal
            BCS LB32F
            JSR LB1CA
            JSR LA83B
            LDA prvOswordBlockCopy
            AND #&F0
            BNE LB32F
            JSR LA905
            CLC
            RTS
			
.LB32F      SEC
            RTS
			
.LB331      CLV
            CLC
            JMP (KEYVL)

;OSBYTE &07 buffer data
;Equivalent to SOUND 3,-15,210,5
.LB336		EQUW &0003							;Channel:	 3
		EQUW &FFF1							;Amplitude:	-15
		EQUW &00D2							;Pitch:		 210
		EQUW &0005							;Duration:	 5

.LB33E		EQUB &02,&08
.LB340		EQUB &0F,&1E,&3C,&78
.LB344		EQUB &F6,&F1
.LB346		EQUB &5A,&82,&B0,&D2

.LB34A		EQUB &06,&0E
.LB34C		EQUB &0F,&07

.LB34E      LDX #&33
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            ASL A
            PHP
            ASL A
            PLP
            PHP
            ROR A
            PLP
            ROR A
            JSR writeUserReg								;Write to RTC clock User area. X=Addr, A=Data

.LB35E      SEC
.LB35F      LDA romselCopy
            PHA
            LDA ramselCopy
            PHA
            AND #&80
            ORA #&40
            STA ramselCopy
            STA ramsel
            LDA romselCopy
            ORA #&40
            STA romselCopy
            STA romsel
            BCC LB3CA

	  LDX #&33
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            PHA									;and save value
            AND #&01								;read first bit (0)
            TAX
            LDA LB33E,X								;read first byte from 2 byte lookup table
            STA prv82+&72								;save at &8272
            PLA
            LSR A									;ditch lsb - already used
            PHA
            AND #&03								;read next two bits (1&2)
            TAX
            LDA LB340,X								;read second byte from 4 byte lookup table
            STA prv82+&73								;save at &8273
            PLA
            LSR A
            LSR A									;ditch next two lsbs - already used
            PHA
            AND #&03								;read next two bits (3&4)
            TAX
            LDA LB346,X								;read third byte from 4 byte lookup table
            STA prv82+&75								;save at &8275
            PLA
            LSR A
            LSR A									;ditch next two lsbs - already used
            AND #&01								;read next bit (0)
            TAX
            LDA LB344,X								;read forth byte from 2 byte lookup table
            STA prv82+&74								;save at &8274
            LDX #&0A								;Select 'Register A' register on RTC: Register &0A
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            AND #&F0
            ORA #&0E
            JSR wrRTCRAM								;Write data from A to RTC memory location X
            LDX #&0B								;Select 'Register B' register on RTC: Register &0B
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            ORA #&40								;Enable Periodic Interrupts
            JSR wrRTCRAM								;Write data from A to RTC memory location X
            LDA #&01
            STA prv82+&76
.LB3CA      LDA prv82+&76
            EOR #&01
            STA prv82+&76
            BEQ LB447
            LDA prv82+&73
            BEQ LB40E
            LDY #&07
.LB3DB      LDA L00A8,Y
            PHA
            DEY
            BPL LB3DB
            LDY #&07
.LB3E4      LDA LB336,Y								;Relocate sound data from &B336-&B33D
            STA L00A8,Y								;to &00A8-&00AF
            DEY
            BPL LB3E4
            LDA prv82+&74
            STA L00AA
            LDA prv82+&75
            STA L00AC
            LDA #&07								;Perform SOUND command
            LDX #&A8								;buffer address &00A8
            LDY #&00
            JSR OSWORD								;OSWORD &07, buffer &00A8
            LDY #&00
.LB402      PLA
            STA L00A8,Y
            INY
            CPY #&08
            BNE LB402
            DEC prv82+&73
.LB40E      LDA prv82+&72
            BNE LB444
            JSR LB331
            BVC LB447
            BPL LB447
            LDX #&33
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            LSR A
            AND #&20
            STA prv82+&76
            LDX #&0B								;Select 'Register B' register on RTC: Register &0B
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            AND #&9F
            ORA prv82+&76
            JSR wrRTCRAM								;Write data from A to RTC memory location X
            LDX #&0A								;Select 'Register A' register on RTC: Register &0A
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            AND #&F0
            JSR wrRTCRAM								;Write data from A to RTC memory location X
            LDA #&76								;Reflect keyboard status in keyboard LEDs
            JSR OSBYTE								;Call OSBYTE
            JMP LB460
			
.LB444      DEC prv82+&72
.LB447      LDX prv82+&76
            LDA SHEILA+&40							;VIA 6522
            AND #&F0
            ORA LB34A,X								;OR with byte from 2 byte lookup table
            STA SHEILA+&40
            LDA SHEILA+&40
            AND #&F0
            ORA LB34C,X								;OR with byte from 2 byte lookup table
            STA SHEILA+&40

.LB460      PLA
            STA ramselCopy
            STA ramsel
            PLA
            STA romselCopy
            STA romsel
            RTS
			
.LB46E      DEX									;Select 'Register B' register on RTC: Register &0B
            JSR LA660								;3 x NOP delay
            STX SHEILA+&38						          	;Strobe in address
            JSR LA660								;3 x NOP delay
            AND SHEILA+&3C							          ;Strobe out data
            JSR LA664
            ASL A
            ASL A
            BCC LB488
            PHA
            CLC
            JSR LB35F
            PLA
.LB488      ASL A
            BCC LB490
            PHA
            JSR LB34E
            PLA
.LB490      ASL A
            BCC LB4AC
            LDX #&44
            JSR readPrivateRam8300X							;read data from Private RAM &83xx (Addr = X, Data = A)
            PHA
            AND #&01
            BEQ LB4A2
            LDY #&09
            JSR OSEVEN
.LB4A2      PLA
            AND #&02
            BEQ LB4AC
            LDX #&49
            JSR LF168								;OSBYTE 143 - Pass service commands to sideways ROM (http://mdfs.net/Docs/Comp/BBC/OS1-20/F135)
.LB4AC      JMP exitSC								;Exit Service Call

.LB4AF      JSR PrvDis								;switch out private RAM
            JSR raiseError								;Goto error handling, where calling address is pulled from stack

            EQUB &80
			EQUS "Mismatch", &00

.LB4BF      JSR PrvDis								;switch out private RAM
            JSR raiseError								;Goto error handling, where calling address is pulled from stack

            EQUB &80
			EQUS "Bad date", &00

.LB4CF      JSR PrvDis								;switch out private RAM
            JSR raiseError								;Goto error handling, where calling address is pulled from stack

            EQUB &80
			EQUS "Bad time", &00

;*TIME Command
.time       JSR PrvEn								;switch in private RAM
            LDA (L00A8),Y							;read first character of command parameter
            CMP #&3D								;check for '='
            BEQ LB50C								;if '=' then set time, else read time
            JSR LA5EF								;store #&05, #&84, #&44 and #&EB to addresses &8220..&8223
            LDA #&FF
            STA prvOswordBlockCopy + 7							;store #&FF to address &8227
            STA prvOswordBlockCopy + 6							;store #&FF to address &8226
            LDA #&00
            STA prvOswordBlockCopy + 4							;store #&00 to address &8224
            LDA #&80
            STA prvOswordBlockCopy + 5							;store #&80 to address &8225
            JSR LA769								;read TIME & DATE information from RTC and store in Private RAM (&82xx)
            JSR LAD63								;format text for output to screen?
            JSR LA5DE								;output TIME & DATE data from address &8000 to screen
.LB506      JSR PrvDis								;switch out private RAM
            JMP exitSC								;Exit Service Call								;
			
.LB50C      INY
            JSR LB2B5
            BCC LB515
            JMP LB4CF								;Error with Bad time
			
.LB515      JSR LA676								;Read 'Seconds', 'Minutes' & 'Hours' from Private RAM (&82xx) and write to RTC
            JMP LB506								;switch out private RAM and exit

;*DATE Command			
.date		JSR PrvEn								;switch in private RAM
            LDA (L00A8),Y							;read first character of command parameter
            CMP #&3D								;check for '='
            BEQ LB552								;if '=' then set date, else read date
            JSR LA5EF								;store #&05, #&84, #&44 and #&EB to addresses &8220..&8223
            LDA prvOswordBlockCopy + 2
            AND #&F0
            STA prvOswordBlockCopy + 2							;store #&40 to address &8222
            JSR LB133
            BCC LB53C
            BVS LB539
            JMP LB4AF								;Error with Mismatch
			
.LB539      JMP LB4BF								;Error with Bad Date

.LB53C      LDA #&00
            STA prvOswordBlockCopy + 4							;store #&00 to address &8224
            LDA #&80
            STA prvOswordBlockCopy + 5							;store #&80 to address &8225
            JSR LAD63								;format text for output to screen?
            JSR LA5DE								;output DATE data from address &8000 to screen
.LB54C      JSR PrvDis								;switch out private RAM
            JMP exitSC								;Exit Service Call								;
			
.LB552      INY
            JSR LB2F5
            BCC LB55B
            JMP LB4BF								;Error with Bad date
			
.LB55B      JSR LA6CB								;Read 'Day of Week', 'Date of Month', 'Month' & 'Year' from Private RAM (&82xx) and write to RTC
            JMP LB54C								;switch out private RAM and exit
			
;Start of CALENDAR * Command
.calend      JSR PrvEn								;switch in private RAM
            JSR LB133
            BCC LB571
            BVS LB56E
            JMP LB4AF
			
.LB56E      JMP LB4BF

.LB571      LDA #&C8
            STA prvOswordBlockCopy + 4
            LDA #&80
            STA prvOswordBlockCopy + 5
            LDA #&05
            STA prvOswordBlockCopy
            LDA #&40
            STA prvOswordBlockCopy + 1
            LDA #&00
            STA prvOswordBlockCopy + 2
            LDA #&F8
            STA prvOswordBlockCopy + 3
            JSR LAD63
            SEC
            LDA #&17
            SBC L00AA
            LSR A
            TAX
            LDA #&20								;' '
.LB59B      JSR OSWRCH
            DEX
            BNE LB59B
            LDX #&00
.LB5A3      LDA prv80+&C8,X
            JSR OSASCI
            CMP #&0D
            BEQ LB5B0
            INX
            BNE LB5A3
.LB5B0      JSR LA9E6
            LDA #&01
            STA prv82+&4A
            LDA #&00
            STA prv82+&4B
.LB5BD      LDY #&00
            STY L00AA								;set buffer pointer
            LDA #&00
            STA L00A8
            LDA #&80
            STA L00A9								;set buffer @ &8000
            LDA prv82+&4A
            LDX #&03
            LDY #&FF
            CLC
            JSR LAAF5
            LDA #&00
            STA prv82+&4C
.LB5D9      LDA #&20								;' '
            JSR LABE2								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
            LDX prv82+&4B
            LDA prv80+&C8,X
            LDX #&03
            JSR LAB3C								;convert to characters, store in buffer XY?Y, increase buffer pointer, save buffer pointer and return
            INC prv82+&4B
            INC prv82+&4C
            LDA prv82+&4C
            CMP #&06
            BCC LB5D9
            LDA #&0D
            JSR LABE2								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
            LDX #&00
.LB5FD      LDA prv80+&00,X
            JSR OSASCI
            CMP #&0D
            BEQ LB60A
            INX
            BNE LB5FD
.LB60A      INC prv82+&4A
            LDA prv82+&4A
            CMP #&08
            BCC LB5BD
            JSR PrvDis								;switch out private RAM
            JMP exitSC								;Exit Service Call
			
.LB61A      INY
.LB61B      PHP
            JSR LB2B5
            BCC LB62D
            PLP
            BCC LB62A
            JSR PrvDis								;switch out private RAM
            JMP syntaxError
			
.LB62A      JMP LB4CF

.LB62D      PLP
            JSR copyPrvAlarmToRtc
            JSR findNextCharAfterSpace								;find next character. offset stored in Y
            LDA (L00A8),Y
            AND #&DF                                                                                ; convert to upper case (imperfectly)
            CMP #'R'
            PHP
            PLA
            LSR A
            LSR A
            PHP
            LDX #&33
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            ASL A
            PLP
            ROR A
            JMP LB67C
			
;*ALARM Command
.alarm      JSR PrvEn								;switch in private RAM
            LDA (L00A8),Y
            CMP #'='
            CLC
            BEQ LB61A
            CMP #'?'
            BEQ LB690
            CMP #vduCr
            BEQ LB690
            JSR L8699
            BCS LB61B
            PHP
            LDX #&33
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            PLP
            BNE LB67C
            AND #&BF
            JSR writeUserReg							;Write to RTC clock User area. X=Addr, A=Data
            LDX #&0B								;Select 'Register B' register on RTC: Register &0B
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            AND #&9F
            JSR wrRTCRAM								;Write data from A to RTC memory location X
            JMP LB6E3
			
.LB67C      ORA #&40
            JSR writeUserReg							;Write to RTC clock User area. X=Addr, A=Data
            LDX #&0B								;Select 'Register B' register on RTC: Register &0B
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            AND #&9F
            ORA #&20
            JSR wrRTCRAM								;Write data from A to RTC memory location X
            JMP LB6E3
			
.LB690      LDA #&40
            STA prvOswordBlockCopy + 1
            LDA #&04
            STA prvOswordBlockCopy + 2
            LDA #&00
            STA prvOswordBlockCopy + 3
            LDA #&FF
            STA prvOswordBlockCopy + 7
            STA prvOswordBlockCopy + 6
            LDA #&00
            STA prvOswordBlockCopy + 4
            LDA #&80
            STA prvOswordBlockCopy + 5
            JSR copyRtcAlarmToPrv
            JSR LAD63
            DEC prvOswordBlockCopy + 1
            JSR LA5DE
            LDA #&2F								;'/'
            JSR OSWRCH								;write to screen
            JSR printSpace								;write ' ' to screen
            LDX #&0B								;Select 'Register B' register on RTC: Register &0B
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            AND #&20
            JSR L86C8
            LDX #&33
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            AND #&80
            BEQ LB6E0
            JSR printSpace								;write ' ' to screen
            LDA #&52								;'R'
            JSR OSWRCH								;write to screen
.LB6E0      JSR OSNEWL								;new line
.LB6E3      JSR PrvDis								;switch out private RAM
            JMP exitSC								;Exit Service Call
			
;OSWORD &0E (14) Read real time clock
.osword0e	JSR stackTransientCmdSpace						;save 8 bytes of data from &A8 onto the stack
            JSR PrvEn								;switch in private RAM
            LDA oswdbtX								;get X register value of most recent OSWORD call
            STA prvOswordBlockOrigAddr							;and save to &8230
            LDA oswdbtY								;get Y register value of most recent OSWORD call
            STA prvOswordBlockOrigAddr + 1							;and save to &8231
            JSR oswordsv							;save XY entry table
            JSR oswd0e_1							;execute OSWORD &0E
            BCS osword0ea							;successful so don't restore XY entry table
            JSR oswordrs							;restore XY entry table
.osword0ea	LDA prvOswordBlockOrigAddr							;get X register value of most recent OSWORD call
            STA oswdbtX								;and restore to &F0
            LDA prvOswordBlockOrigAddr + 1							;get Y register value of most recent OSWORD call
            STA oswdbtY								;and restore to &F1
            LDA #&0E								;load A register value of most recent OSWORD call (&0E)
            STA oswdbtA								;and restore to &EF
            JSR PrvDis								;switch out private RAM

            JMP osword49b							;restore 8 bytes of data to &A8 from the stack and exit
			
;OSWORD &49 (73) - Integra-B calls
.osword49	JSR stackTransientCmdSpace						;save 8 bytes of data from &A8 onto the stack
            JSR PrvEn								;switch in private RAM
            LDA oswdbtX								;get X register value of most recent OSWORD call
            STA prvOswordBlockOrigAddr							;and save to &8230
            LDA oswdbtY								;get Y register value of most recent OSWORD call
            STA prvOswordBlockOrigAddr + 1							;and save to &8231
            JSR oswordsv							;save XY entry table
            JSR oswd49_1							;execute OSWORD &49
            BCS osword49a							;successful so don't restore XY entry table
            JSR oswordrs							;restore table
.osword49a	LDA prvOswordBlockOrigAddr							;get X register value of most recent OSWORD call
            STA oswdbtX								;and restore to &F0
            LDA prvOswordBlockOrigAddr + 1							;get Y register value of most recent OSWORD call
            STA oswdbtY								;and restore to &F1
            LDA #&49								;load A register value of most recent OSWORD call (&49)
            STA oswdbtA								;and restore to &EF
            JSR PrvDis								;switch out private RAM

.osword49b	JSR unstackTransientCmdSpace						;restore 8 bytes of data to &A8 from the stack
            JMP exitSC								;Exit Service Call
			
;Save OSWORD XY entry table
.oswordsv	LDA prvOswordBlockOrigAddr
            STA L00AE
            LDA prvOswordBlockOrigAddr + 1
            STA L00AF
            LDY #&0F
.oswordsva	LDA (L00AE),Y
            STA prvOswordBlockCopy,Y
            DEY
            BPL oswordsva
            RTS
			
;Restore OSWORD XY entry table
.oswordrs	LDA prvOswordBlockOrigAddr
            STA L00AE
            LDA prvOswordBlockOrigAddr + 1
            STA L00AF
            LDY #&0F
.oswordrsa	LDA prvOswordBlockCopy,Y
            STA (L00AE),Y
			DEY
            BPL oswordrsa
            RTS
			
;Clear RTC buffer
.LB774      LDY #&0F
            LDA #&00
.LB778      STA prvOswordBlockCopy,Y
            DEY
            BPL LB778
            RTS
			
;OSWORD &0E (14) Read real time clock XY?0 parameter lookup code
.oswd0e_1   LDA prvOswordBlockCopy							;get XY?0 value
            ASL A									;x2 (each entry in lookup table is 2 bytes)
            TAY
            LDA oswd0elu+1,Y						;get low byte
            PHA										;and push
            LDA oswd0elu,Y							;get high byte
            PHA										;and push
            RTS										;jump to parameter lookup address

;OSWORD &0E (14) Read real time clock XY?0 parameter lookup table
.oswd0elu	EQUW LB81E-1							;XY?0=0: Read time and date in string format
			EQUW LB835-1							;XY?0=1: Read time and date in binary coded decimal (BCD) format
			EQUW LB844-1							;XY?0=2: Convert BCD values into string format

;OSWORD &49 (73) - Integra-B calls XY?0 parameter lookup code
.oswd49_1	SEC
            LDA prvOswordBlockCopy							;get XY?0 value
            SBC #&60								;XY?0 is in range &60-&6F. Convert to &00-&0F for lookup purposes
            ASL A									;x2 (each entry in lookup table is 2 bytes)
            TAY
            LDA oswd49lu+1,Y						;get low byte
            PHA										;and push
            LDA oswd49lu,Y							;get high byte
            PHA										;and push
.LB7A3	  RTS										;jump to parameter lookup address
			
;OSWORD &49 (73) - Integra-B calls XY?0 parameter lookup table
.oswd49lu		EQUW LB899-1							;XY?0=&60: Function TBC
		EQUW LB891-1							;XY?0=&61: Function TBC
		EQUW LB89C-1							;XY?0=&62: Function TBC
		EQUW LB7A3-1							;XY?0=&63: Function TBC - No function?
		EQUW LB8C6-1							;XY?0=&64: Function TBC
		EQUW LB8D8-1							;XY?0=&65: Function TBC
		EQUW LB8DD-1							;XY?0=&66: Function TBC
		EQUW LB8E2-1							;XY?0=&67: Function TBC
		EQUW LB8AC-1							;XY?0=&68: Function TBC
		EQUW LB8B1-1							;XY?0=&69: Function TBC
		EQUW LB8FC-1							;XY?0=&6A: Function TBC
		EQUW LB901-1							;XY?0=&6B: Function TBC
			
.LB7BC	  BIT prvOswordBlockCopy + 7
            BMI LB7F9
            BIT tubePresenceFlag								;check for Tube - &00: not present, &ff: present
            BPL LB7F9
.LB7C6      LDA #tubeEntryClaim + tubeClaimId
            JSR tubeEntry
            BCC LB7C6
            CLC
            LDA prvOswordBlockOrigAddr
            ADC #&04
            TAX
            LDA prvOswordBlockOrigAddr + 1
            ADC #&00
            TAY
            LDA #&01
            JSR tubeEntry
            LDY #&00
.LB7E1      LDA prv80+&00,Y
.LB7E4      BIT SHEILA+&E4
            BVC LB7E4
            STA SHEILA+&E5
            INY
            CPY prvOswordBlockCopy + 1
            BNE LB7E1
            LDA #tubeEntryRelease + tubeClaimId
            JSR tubeEntry
            CLC
            RTS
			
.LB7F9      LDA prvOswordBlockOrigAddr
            STA L00A8
            LDA prvOswordBlockOrigAddr + 1
            STA L00A9
            LDY #&04
            LDA (L00A8),Y
            TAX
            INY
            LDA (L00A8),Y
            STA L00A9
            STX L00A8
            LDY #&00
.LB811      LDA prv80+&00,Y
            STA (L00A8),Y
            INY
            CPY prvOswordBlockCopy + 1
            BNE LB811
            CLC
            RTS
			
;OSWORD &0E (14) Read real time clock
;XY&0=0: Read time and date in string format
.LB81E      JSR LA769								;read TIME & DATE information from RTC and store in Private RAM (&82xx)
.LB821      JSR LA5EF								;store #&05, #&84, #&44 and #&EB to addresses &8220..&8223
            LDA prvOswordBlockOrigAddr							;get OSWORD X register (lookup table LSB)
            STA prvOswordBlockCopy + 4							;save OSWORD X register (lookup table LSB)
            LDA prvOswordBlockOrigAddr + 1							;get OSWORD Y register (lookup table MSB)
            STA prvOswordBlockCopy + 5							;save OSWORD Y register (lookup table MSB)
            JSR LAD63
            SEC
            RTS
			
;OSWORD &0E (14) Read real time clock
;XY&0=1: Read time and date in binary coded decimal (BCD) format
.LB835      JSR LA769								;read TIME & DATE information from RTC and store in Private RAM (&82xx)
            LDY #&06
.LB83A      JSR LB85A
            STA (oswdbtX),Y
            DEY
            BPL LB83A
            SEC
            RTS
			
;OSWORD &0E (14) Read real time clock
;XY&0=2: Convert BCD values into string format
.LB844      LDX #&06
.LB846      LDA prvOswordBlockCopy + 1,X
            JSR LB87A
            STA prvOswordBlockCopy + 9,X
            DEX
            BPL LB846
            LDA #&13
            STA prvOswordBlockCopy + 8
            JMP LB821
			
.LB85A      LDA prvOswordBlockCopy + 9,Y
            SEC
            SBC #&64
            BCS LB85A
            ADC #&64
            LDX #&FF
            SEC
.LB867      INX
            SBC #&0A
            BCS LB867
            ADC #&0A
            STA prvOswordBlockCopy + 9,Y
            TXA
            ASL A
            ASL A
            ASL A
            ASL A
            ORA prvOswordBlockCopy + 9,Y
            RTS
			
.LB87A      PHA
            AND #&0F
            STA prv82+&4E
            PLA
            AND #&F0
            LSR A
            STA prv82+&4F
            LSR A
            LSR A
            CLC
            ADC prv82+&4F
            ADC prv82+&4E
            RTS

;XY?0=&61
;OSWORD &49 (73) - Integra-B calls
.LB891      JSR LB774								;Clear RTC buffer @ &8220-&822F
            JSR LA769								;read TIME & DATE information from RTC and store in Private RAM (&82xx)
            CLC
            RTS
			
;XY?0=&60
;OSWORD &49 (73) - Integra-B calls
.LB899		JSR LA769								;read TIME & DATE information from RTC and store in Private RAM (&82xx)

;XY?0=&62
;OSWORD &49 (73) - Integra-B calls
.LB89C      LDA #&00
	  STA prvOswordBlockCopy + 4
            LDA #&80
            STA prvOswordBlockCopy + 5							;set buffer address to &8000
            JSR LAD63
            JMP LB7BC
			
;XY?0=&68
;OSWORD &49 (73) - Integra-B calls
.LB8AC		JSR LAFF9
            CLC
            RTS
			
;XY?0=&69
;OSWORD &49 (73) - Integra-B calls
.LB8B1		LDA #&00
            STA prvOswordBlockCopy + 4
            LDA #&80
            STA prvOswordBlockCopy + 5
            JSR LA9E6
            LDA #&2A
            STA prvOswordBlockCopy + 1
            JMP LB7BC
			
;XY?0=&64
;OSWORD &49 (73) - Integra-B calls
.LB8C6		JSR LB774
            JSR copyRtcAlarmToPrv
            LDX #&0B								;Select 'Register B' register on RTC: Register &0B
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            AND #&60
            STA prvOswordBlockCopy + 1
            CLC
            RTS
			
;XY?0=&65
;OSWORD &49 (73) - Integra-B calls
.LB8D8		JSR LA676								;Read 'Seconds', 'Minutes' & 'Hours' from Private RAM (&82xx) and write to RTC
            SEC
            RTS
			
;XY?0=&66
;OSWORD &49 (73) - Integra-B calls
.LB8DD		JSR LA6CB								;Read 'Day of Week', 'Date of Month', 'Month' & 'Year' from Private RAM (&82xx) and write to RTC
            SEC
            RTS
			
;XY?0=&67
;OSWORD &49 (73) - Integra-B calls
.LB8E2		JSR copyPrvAlarmToRtc
            LDA prvOswordBlockCopy + 1
            AND #&60
            STA prvOswordBlockCopy + 1
            LDX #&0B								;Select 'Register B' register on RTC: Register &0B
            JSR rdRTCRAM								;Read data from RTC memory location X into A
            AND #&9F
            ORA prvOswordBlockCopy + 1
            JSR wrRTCRAM								;Write data from A to RTC memory location X
            SEC
            RTS
			
;XY?0=&6A
;OSWORD &49 (73) - Integra-B calls
.LB8FC		JSR LADCB
            CLC
            RTS
			
;XY?0=&6B
;OSWORD &49 (73) - Integra-B calls
.LB901		JSR LAE2C
            CLC
            RTS

.LB906      JMP exitSCa								;restore service call parameters and exit

;Break - Service call &06
.service06	LDA L00FE
            CMP #&FF
            BNE LB906
            LDX oswdbtX ; SFTODO: seems a bit odd using this address in this service call
            TXS
            LDA #&88
            PHA
            LDA L0102,X
            PHA
            LDA L00FC
            PHA
            LDA L0101,X
            PHA
            LDA #&FF
            STA L0101,X
            LDA L024A
            STA L0102,X
            LDA L00FD
            CMP #&B4
            BEQ LB936
.LB931      PLA
            TAX
            PLA
            PLP
            RTS
			
.LB936      LDA romselCopy
            ORA #&80
            STA romselCopy
            STA romsel
            TSX
            LDA L0102,X
            STA (L00D6),Y
            JMP LB931

; Set MEMSEL. This means that main/video memory will be paged in at &3000-&7FFF
; regardless of SHEN.
; SFTODO: Maybe change this to something like pageInMainVideoMemory? But for now
; it's probably better to make the hardware paging operation the focus.
.setMemsel
{
.LB948      PHA
            LDA romselCopy
            ORA #romselMemsel
            STA romselCopy
            STA romsel
            PLA
            RTS
}

;relocation code
; Copy our code stub into the OS printer buffer.
; SFTODO: This only has one caller at the moment and could be inlined.
.installOSPrintBufStub
{
bytesToCopy = &40
ASSERT romCodeStubEnd - romCodeStub <= bytesToCopy
.LB954      LDX #bytesToCopy - 1
.LB956      LDA romCodeStub,X
            STA osPrintBuf,X
            DEX
            BPL LB956
            ; Patch the stub so it contains our bank number.
            LDA romselCopy
            AND #&0F
            STA osPrintBuf + (romCodeStubLoadBankImm + 1 - romCodeStub)
            RTS
}

; Code stub which is copied into the OS printer buffer at runtime by
; installOSPrintBufStub. The first 7 instructions are identical JSRs to the RAM
; copy of romCodeStubCallIBOS; these are (SFTODO: confirm this) installed as the
; targets of various non-extended vectors (SFTODO: by which subroutine?). The
; code at romCodeStubCallIBOS pages us in, calls the vectorEntry subroutine and
; then pages the previous ROM back in afterwards. vectorEntry is able to
; distinguish which of the 7 JSRs transferred control (and therefore which
; vector is being called) by examining the return address pushed onto the stack
; by that initial JSR.
;
; Doing all this avoids the use of the OS extended vector mechanism, which is
; relatively slow (particularly important for WRCHV, which gets called for every
; character output to the screen) and doesn't allow for vector chains.
;
; Note that while we have to save the originally paged in bank from romselCopy
; and restore it afterwards for obvious reasons (the caller is very likely
; directly or indirectly relying on this, e.g. a BASIC program will need the
; BASIC ROM to remain paged in after making an OS call which goes to IBOS!),
; this *also* has the effect of restoring the previous values of PRVEN and MEMSEL.
; SFTODO: I would like to get the whole ROM disassembled first before writing a
; permanent comment, but this is why e.g. rdchvHandler can do JSR setMemsel without
; explicitly reverting that change.
; SFTODO: Experience with Ozmoo suggests it's *probably* OK, but does IBOS always
; restore RAMSEL/RAMID to their original values if it changes them? Or at least the
; PRVSx bits?
.romCodeStub
ramCodeStub = osPrintBuf ; SFTODO: use ramCodeStub instead of osPrintBuf in some/all places?
{
.LB967      JSR ramCodeStubCallIBOS ; BYTEV
            JSR ramCodeStubCallIBOS ; WORDV
            JSR ramCodeStubCallIBOS ; WRCHV
            JSR ramCodeStubCallIBOS ; RDCHV
            JSR ramCodeStubCallIBOS ; INSV
            JSR ramCodeStubCallIBOS ; REMV
            JSR ramCodeStubCallIBOS ; CNPV
.romCodeStubCallIBOS
ramCodeStubCallIBOS = ramCodeStub + (romCodeStubCallIBOS - romCodeStub)
.LR0895     PHA					;becomes address &895 when relocated.
            PHP
            LDA romselCopy
            PHA
.^romCodeStubLoadBankImm
            LDA #&00				;The value at this address is patched at run time by installOSPrintBufStub
            STA romselCopy
            STA romsel
            JSR vectorEntry
            PLA
            STA romselCopy
            STA romsel
            PLP
            PLA
            RTS
}
.romCodeStubEnd
ramCodeStubEnd = ramCodeStub + (romCodeStubEnd - romCodeStub)
; The next part of osPrintBuf is used to hold a table of 7 original OS (parent)
; vectors. This is really a single table, but because the 7 vectors of interest
; aren't contiguous in the OS vector table it's sometimes helpful to consider it
; as having two separate parts.
parentVectorTbl = ramCodeStubEnd
parentVectorTbl1 = parentVectorTbl
; The original OS (parent) values of BYTEV, WORDV, WRCHV and RDCHV are copied to
; parentVectorTbl1 in that order before installing our own handlers.
parentBYTEV = parentVectorTbl1
parentVectorTbl2 = parentVectorTbl1 + 4 * 2 ; 4 vectors, 2 bytes each
; The original OS (parent) values of INSV, REMV and CNPV are copied to
; parentVectorTbl2 in that order before installing our own handlers.
parentVectorTbl2End = parentVectorTbl2 + 3 * 2 ; 3 vectors, 2 bytes each
ASSERT parentVectorTbl2End <= osPrintBuf + &40

; Restore A, X, Y and the flags from the stacked copies pushed during the vector
; entry process. The stack must have the same layout as described in the big
; comment in vectorEntry; note that the addresses in this subroutine are two
; bytes higher because we were called via JSR so we need to allow for our own
; return address on the stack.
.restoreOrigVectorRegs
{
.LB994      TSX
            LDA L0108,X ; get original flags
            PHA
            LDA L0109,X ; get original A
            PHA
            LDA L0104,X ; get original X
            PHA
            ; SFTODO: We could save a byte here by doing LDY L0103,X directly.
            LDA L0103,X ; get original Y
            TAY
            PLA
            TAX
            PLA
            PLP
            RTS
}

; This subroutine is the inverse of restoreOrigVectorRegs; it takes the current
; values of A, X, Y and the flags and overwrites the stacked copies with them
; so they will be restored on returning from the vector handler.
.updateOrigVectorRegs
{
            ; At this point the stack is as described in the big comment in
            ; vectorEntry but with the return address for this subroutine also
            ; pushed onto the stack.
.LB9AA      PHP
            PHA
            TXA
            PHA
            TYA
            TSX
            ; So at this point the stack is as described in the big comment in
            ; vectorEntry but with everything moved up five bytes (X=S-5, if S
            ; is the value of the stack pointer in that comment).
            STA L0106,X ; overwrite original stacked Y
            PLA
            STA L0107,X ; overwrite original stacked X
            PLA
            STA L010C,X ; overwrite original stacked A
            PLA
            STA L010B,X ; overwrite original stacked flags
.LB9BF      RTS
}

; Table of vector handlers used by vectorEntry; addresses have -1 subtracted
; because we transfer control to these via an RTS instruction. The odd bytes
; between the addresses are there to match the spacing of the JSR instructions
; at osPrintBuf; the actual values are irrelevant and will never be used.
; SFTODO: Are they really unused? Maybe there's some code hiding somewhere,
; but nothing references this label except the code at vectorEntry. It just
; seems a bit odd these bytes aren't 0.
ibosBYTEVIndex = 0
ibosWORDVIndex = 1
ibosWRCHVIndex = 2
ibosRDCHVIndex = 3
ibosINSVIndex = 4
ibosREMVIndex = 5
ibosCNPVIndex = 6
.vectorHandlerTbl	EQUW bytevHandler-1
		EQUB &0A
		EQUW wordvHandler-1
		EQUB &0C
		EQUW wrchvHandler-1
		EQUB &0E
		EQUW rdchvHandler-1
		EQUB &10
		EQUW insvHandler-1
		EQUB &2A
		EQUW remvHandler-1
		EQUB &2C
		EQUW cnpvHandler-1
		EQUB &2E

; Control arrives here via ramCodeStub when one of the vectors we've claimed is
; called.
.vectorEntry
{
.LB9D5      TXA
            PHA
            TYA
            PHA
            ; At this point the stack looks like this:
            ;   &101,S  Y stacked by preceding instructions
            ;   &102,S  X stacked by preceding instructions
            ;   &103,S  return address from "JSR vectorEntry" (low)
            ;   &104,S  return address from "JSR vectorEntry" (high)
            ;   &105,S  previously paged in ROM bank stacked by romCodeStubCallIBOS
            ;   &106,S  flags stacked by romCodeStubCallIBOS
            ;   &107,S  A stacked by romCodeStubCallIBOS
            ;   &108,S  return address from "JSR ramCodeStubCallIBOS" (low)
            ;   &109,S  return address from "JSR ramCodeStubCallIBOS" (high)
            ;   &10A,S  x (caller's data; nothing to do with us)
            ; The low byte of the return address at &108,S will be the address
            ; of the JSR ramCodeStubCallIBOS plus 2. We mask off the low bits
            ; (which are sufficient to distinguish the 7 different callers) and
            ; use them to transfer control to the handler for the relevant
            ; vector.
            TSX
            LDA L0108,X
            AND #&3F
            TAX
            LDA vectorHandlerTbl-1,X
            PHA
            LDA vectorHandlerTbl-2,X
            PHA
            RTS
}

; Clean up and return from a vector handler; we have dealt with the call and
; we're not going to call the parent handler. At this point the stack should be
; exactly as described in the big comment in vectorEntry; note that this code is
; reached via JMP so there's no extra return address on the stack as there is in
; restoreOrigVectorRegs.
.returnFromVectorHandler
{
; SFTODO: This is really just shuffling the stack down to remove the return
; address from "JSR ramCodeStubCallIBOS"; can we rewrite it more compactly using
; a loop?
.LB9E9      TSX
            LDA L0107,X
            STA L0109,X
            LDA L0106,X
            STA L0108,X
            LDA L0105,X
            STA L0107,X
            LDA L0104,X
            STA L0106,X
            LDA L0103,X
            STA L0105,X
            LDA L0102,X
            STA L0104,X
            LDA L0101,X
            STA L0103,X
            PLA
            PLA
            ; At this point the stack looks like this:
            ;   &101,S  Y stacked by preceding instructions
            ;   &102,S  X stacked by preceding instructions
            ;   &103,S  return address from "JSR vectorEntry" (low)
            ;   &104,S  return address from "JSR vectorEntry" (high)
            ;   &105,S  previously paged in ROM bank stacked by romCodeStubCallIBOS
            ;   &106,S  flags stacked by romCodeStubCallIBOS
            ;   &107,S  A stacked by romCodeStubCallIBOS
            ;   &108,S  x (caller's data; nothing to do with us)
            ; We now restore Y and X and RTS from "JSR vectorEntry" in ramCodeStub,
            ; which will restore the previously paged in ROM, the flags and then A,
            ; so the vector's caller will see the Z/N flags reflecting A, but
            ; otherwise preserved.
            PLA
            TAY
            PLA
            TAX
            RTS
}

; Restore the registers and pass the call onto the parent vector handler for
; vector A (using the ibos*Index numbering). At this point the stack should be
; exactly as described in the big comment in vectorEntry; note that this code is
; reached via JMP so there's no extra return address on the stack as there is in
; restoreOrigVectorRegs.
.forwardToParentVectorTblEntry
{
.LBA1B      TSX
            ASL A
            TAY
            ; We need to subtract 1 from the destination address because we're
            ; going to transfer control via RTS, which will add 1.
            SEC
            LDA parentVectorTbl,Y
            SBC #&01
            STA L0108,X ; overwrite low byte of return address from "JSR ramCodeStubCallIBOS"
            LDA parentVectorTbl+1,Y
            SBC #&00
            STA L0109,X ; overwrite high byte
            PLA
            TAY
            PLA
            TAX
            RTS
}

; Aries/Watford shadow RAM access (http://beebwiki.mdfs.net/OSBYTE_%266F)
.osbyte6FHandler
{
.LBA34      JSR L8A7B
            JMP LBACB
}

; Read key with time limit/read machine type (http://beebwiki.mdfs.net/OSBYTE_%2681)
.osbyte81Handler
{
.LBA3A      CPX #&00
            BNE osbyte87Handler
            CPY #&FF
            BNE osbyte87Handler
            LDX #prvOsMode - prv83								;select OSMODE
            JSR readPrivateRam8300X								;read data from Private RAM &83xx (Addr = X, Data = A)
            BEQ LBA56								;Branch if OSMODE=0
            CMP #&01								;Check if OSMODE=1
            BEQ LBA56								;Branch if OSMODE=1
            TAX
            LDA LBA5D,X								;Get value from lookup table
            TAX									;and transfer to X
            LDY #&00
            BEQ LBACB								;jump to code for OSMODE 2-5
.LBA56      LDX #&00
            LDA #&81
            JMP LBB1C								;jump to code for OSMODE 0-1
}
			
;OSMODE lookup table
.LBA5D		EQUB &01								;OSMODE 0 - Not Used
		EQUB &01								;OSMODE 1 - Not Used
		EQUB &FB								;OSMODE 2
		EQUB &FD								;OSMODE 3
		EQUB &FB								;OSMODE 4
		EQUB &F5								;OSMODE 5
		EQUB &01								;OSMODE 6 - No such mode
		EQUB &01								;OSMODE 7 - No such mode

.jmpParentBYTEV
{
.LBA65      JMP (parentBYTEV)
}

.bytevHandler
{
.LBA68	  JSR restoreOrigVectorRegs
            ; SFTODO: Is there any chance of saving a few bytes by converting this to a
            ; jump table?
            CMP #&6F
            BEQ osbyte6FHandler
            CMP #&98
            BEQ osbyte98Handler
            CMP #&87
            BEQ osbyte87Handler
            CMP #&84
            BEQ osbyte84Handler
            CMP #&85
            BEQ osbyte85Handler
            CMP #&8E
            BEQ osbyte8EHandler
            CMP #&00
            BEQ osbyte00Handler
            CMP #&81
            BEQ osbyte81Handler
            LDA #ibosBYTEVIndex
            JMP forwardToParentVectorTblEntry
}

; Read character at text cursor and screen mode (http://beebwiki.mdfs.net/OSBYTE_%2687)
.osbyte87Handler
{
.LBA90      JSR setMemsel
            JMP LBB1C
}

; Examine buffer status (http://beebwiki.mdfs.net/OSBYTE_%2698)
.osbyte98Handler
{
.LBA96      JSR jmpParentBYTEV
            BCS LBACB
            LDA ramselCopy
            PHA
            ORA #&40
            STA ramselCopy
            STA ramsel
            LDA romselCopy
            PHA
            ORA #&40
            STA romselCopy
            STA romsel
            LDA prvOsMode						;read OSMODE
            CMP #&02
            PLA
            STA romselCopy
            STA romsel
            PLA
            STA ramselCopy
            STA ramsel
            BCC LBACB
            CLC
            LDA (L00FA),Y
            TAY
            LDA #&98
}
.LBACB      JSR updateOrigVectorRegs
            JMP returnFromVectorHandler

; Read top of user memory (http://beebwiki.mdfs.net/OSBYTE_%2684)
.osbyte84Handler
{
.LBAD1      PHA
            LDA vduStatus
            AND #&10
            BNE LBAE9
            PLA
            JMP LBB1C
}

; Read base of display RAM for a given mode (http://beebwiki.mdfs.net/OSBYTE_%2685)
.osbyte85Handler
{
.LBADC      PHA
            TXA
            BMI LBAE9
            LDA osShadowRamFlag
            BEQ LBAE9
            PLA
            JMP LBB1C
}
			
.LBAE9      PLA
            LDX #&00
            LDY #&80
            JMP LBACB

; Enter language ROM (http://beebwiki.mdfs.net/OSBYTE_%268E)
.osbyte8EHandler
{
.LBAF1      LDA #&8F								;Select Issue paged ROM service request
            LDX #&2A								;Service type &2A
            LDY #&00
            JSR OSBYTE								;Execute Issue paged ROM service request
            JSR restoreOrigVectorRegs
            JMP LBB1C
}

; Identify host/operating system (http://beebwiki.mdfs.net/OSBYTE_%2600)
.osbyte00Handler
{
.LBB00      TXA
            PHA
            LDX #prvOsMode - prv83								;select OSMODE
            JSR readPrivateRam8300X								;read data from Private RAM &83xx (Addr = X, Data = A)
            BEQ LBB18								;Branch if OSMODE=0
            CMP #&04								;OSMODE 4?
            BNE LBB0F								;Branch if OSMODE<>4 (OSMODE 1-3)
            LDA #&02
.LBB0F      TAX										;OSMODE 1 = 1, OSMODE 2,4 = 2, OSMODE 3 = 3
            PLA
            BEQ LBB22								;Output OSMODE to screen.
            LDA #&00
            JMP LBACB
}
			
.LBB18      PLA
            TAX
            LDA #&00
.LBB1C      JSR jmpParentBYTEV
            JMP LBACB
			
.LBB22      LDX #&00								;start at offset 0
.LBB24      LDA LBB3C,X								;relocate error code from &BB3C
            STA L0100,X								;to &100
            INX
            CPX #&15								;until &15
            BNE LBB24								;loop
            LDX #prvOsMode - prv83								;select OSMODE
            JSR readPrivateRam8300X								;read data from Private RAM &83xx (Addr = X, Data = A)
            ORA #&30								;convert OSMODE to character printable OSMODE (OSMODE = OSMODE + &30)
            STA L0113								;write OSMODE character to error text
            JMP L0100								;Generate BRK and error

.LBB3C		EQUB &00,&F7
			EQUS "OS 1.20 / OSMODE 0", &00

.LBB51      JMP (L08AF)

.wordvHandler
{
.LBB54		JSR restoreOrigVectorRegs
            CMP #&09
            BNE LBB67
            JSR setMemsel
            JSR LBB51
            JSR updateOrigVectorRegs
            JMP returnFromVectorHandler

.LBB67      LDA #ibosWORDVIndex
            JMP forwardToParentVectorTblEntry
}

{
.jmpParentRDCHV
.LBB6C      JMP (parentVectorTbl + ibosRDCHVIndex * 2)

; It seems a bit counter-intuitive that IBOS needs a RDCHV handler at all, but I
; believe this is needed so cursor editing can work - the OS will try to read
; from screen memory to work out what character is currently on the screen when
; copying text. OS 1.20 doesn't call OSBYTE &87 to read the character, it just
; calls its own internal OSBYTE &87 implementation directly via JSR.
.^rdchvHandler
.LBB6F	  JSR setMemsel
            JSR restoreOrigVectorRegs
            JSR jmpParentRDCHV
            JSR updateOrigVectorRegs
            JMP returnFromVectorHandler
}

.jmpParentWRCHV
{
.LBB7E      JMP (parentVectorTbl + ibosWRCHVIndex * 2)
}

.newMode
{
            ; We're processing OSWRCH with A=vduSetMode. That is only actually a
            ; set mode call if we're not part-way through a longer VDU sequence
            ; (e.g. VDU 23,128,22,...), so check that and set modeChangeState to 1 if we
            ; *are* going to change mode.
.LBB81      PHA
            LDA negativeVduQueueSize
            BNE LBB8C
            ; SFTODO: I think we know modeChangeState is 0 here, so we could just do INC modeChangeState.
            LDA #modeChangeStateSeenVduSetMode
            STA modeChangeState
.LBB8C      PLA
            JMP processWrchv
}

; The following scope is the WRCHV handler; the entry point is at wrchvHandler half way down.
{
; We're processing the second byte of a vduSetMode command, i.e. we will change
; mode when we forward this byte to the parent WRCHV.
.selectNewMode
.LBB90      PLA                                                                                     ;get original OSWRCH A=new mode
            PHA                                                                                     ;save it again
            CMP #&80
            BCS enteringShadowMode
            LDA osShadowRamFlag
            BEQ enteringShadowMode
            ; SFTODO: Aren't the next two instructions pointless? maybeSwapShadow2 immediately does LDA vduStatus.
            PLA                                                                                     ;get original OSWRCH A=new mode
            PHA                                                                                     ;save it again
            JSR maybeSwapShadow2
            LDA ramselCopy								;get RAM copy of RAMSEL
            NOT_AND ramselShen							;clear Shadow RAM enable bit
            STA ramselCopy								;and save RAM copy of RAMSEL
            STA ramsel							          ;save RAMSEL
            PLA                                                                                     ;get original OSWRCH A=new mode
            PHA                                                                                     ;save it again
            AND #&7F								;clear Shadow RAM enable bit SFTODO: isn't this redundant? We'd have done "BCS enteringShadowMode" above if top bit was set, wouldn't we?
            LDX #prvSFTODOMODE - prv83
            JSR writePrivateRam8300X							;write data to Private RAM &83xx (Addr = X, Data = A)
            LDA #modeChangeStateEnteringNonShadowMode
            STA modeChangeState
            PLA
            JMP processWrchv

.enteringShadowMode
.LBBBD      LDA ramselCopy								;get RAM copy of RAMSEL
            ORA #ramselShen								;set Shadow RAM enable bit
            STA ramselCopy								;and save RAM copy of RAMSEL
            STA ramsel							          ;save RAMSEL
            JSR maybeSwapShadow1
            PLA
            PHA
            ORA #&80								;set Shadow RAM enable bit
            LDX #prvSFTODOMODE - prv83
            JSR writePrivateRam8300X							;write data to Private RAM &83xx (Addr = X, Data = A)
            LDA #modeChangeStateEnteringShadowMode
            STA modeChangeState
            PLA
            JMP processWrchv

.checkOtherModeChangeStates
.LBBDD      CMP #modeChangeStateEnteringNonShadowMode
            BNE wrchvHandlerDone
            BEQ adjustCrtcHorz

.^wrchvHandler
.LBBE3	  JSR restoreOrigVectorRegs
            PHA
            LDA modeChangeState
            BNE selectNewMode
            PLA
            CMP #vduSetMode
            BEQ newMode
.^processWrchv ; SFTODO: not a great name...
.LBBF1      JSR setMemsel
            JSR jmpParentWRCHV
            PHA
            LDA modeChangeState
            CMP #modeChangeStateEnteringShadowMode
            BNE checkOtherModeChangeStates
            LDA vduStatus
            ORA #vduStatusShadow
            STA vduStatus
.adjustCrtcHorz
            ; SFTODO: There seems to be an undocumented feature of IBOS which
            ; will perform a horizontal screen shift (analogous to the vertical
            ; shift controlled by *TV/*CONFIGURE TV) based on userRegHorzTV.
            ; This is not exposed in *CONFIGURE/*STATUS, but it does seem to
            ; work if you use *FX162,54 to write directly to the RTC register.
            ; In a modified IBOS this should probably either be removed to save
            ; space or exposed via *CONFIGURE/*STATUS.
.LBC05      LDX #userRegHorzTV
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            CLC
            ADC #&62
            LDX currentMode
            CPX #&04
            BCC LBC1C
            LSR A
            CPX #&07
            BNE LBC1C
            CLC
            ADC #&04
.LBC1C      LDX #&02
            STX crtcHorzTotal
            STA crtcHorzDisplayed
            LDA #modeChangeStateNone
            STA modeChangeState
.^wrchvHandlerDone
.LBC29      PLA
            JMP returnFromVectorHandler
}

{
; SFTODO: The next two subroutines are probably effectively saying "do nothing
; if the shadow state hasn't changed, otherwise do swapShadowIfShxEnabled". I
; have given them poor names for now and should revisit this once exatly when
; they're called becomes clearer.
; SFTODO: This has only one caller
.^maybeSwapShadow1
.LBC2D      LDA vduStatus								;get VDU status
            AND #vduStatusShadow							;test bit 4
            BEQ swapShadowIfShxEnabled							;and branch if clear
            RTS

; SFTODO: This has only one caller
.^maybeSwapShadow2
.LBC34      LDA vduStatus								;get VDU status
            AND #vduStatusShadow        						;test bit 4
            ; SFTODO: Rewriting the next two lines as "BEQ some-rts-somewhere:FALLTHROUGH_TO swapShadowIfShxEnabled" would save a byte.
            BNE swapShadowIfShxEnabled							;and branch if clear
            RTS

; If SHX is enabled, swap the contents of main and shadow RAM between
; &3000-&7FFF. SFTODO: *personal opinion alert* AIUI, Acorn sideways RAM on the
; B+ and M128 behaves as if SHX is always enabled. I think the only reason to
; not always have SHX enabled is that it slows down mode changes. If that's
; right, could we (perhaps keeping SHX off as an option just for the sake of it)
; make this swap so fast it's unnoticeable by using 256 bytes of private RAM to
; do the swap a page at a time, reducing the number of MEMSEL toggles we need to
; do (currently we toggle twice per byte of screen memory) and speeding things
; up?
.swapShadowIfShxEnabled
.LBC3B      LDX #(prvShx - prv83)							;select SHX register (&08: On, &FF: Off) SFTODO: 08->00?
            JSR readPrivateRam8300X							;read data from Private RAM &83xx (Addr = X, Data = A)
            BEQ rts                                                                                 ;nothing to do if SHX off
            ; SFTODO: Why does IBOS play around with these CRTC registers at
            ; all, anywhere? This bit of code seems particularly odd because it
            ; seems to use fixed values, unlike the ones we calculate elsewhere.
            ; Is it trying to black out the screen during the swap?
            LDA #&08
            STA crtcHorzTotal
            LDA #&F0
            STA crtcHorzDisplayed
            ; SFTODO: Next few lines are temporarily (note we PHA the old romselCopy)
            ; clearing PRVEN/MEMSEL
            ; SFTODO: Since we use EOR to toggle MEMSEL in the swap loop,
            ; couldn't we get away with not doing this (and of course not bother
            ; resetting the original value afterwards either)? It doesn't matter
            ; if MEMSEL is currently set or not, since the operation is
            ; symmetrical, and we'd do an even number of toggles so we'd finish
            ; in the original state.
            LDA romselCopy
            PHA
            AND #&0F
            STA romselCopy
            STA romsel
            ; We're going to L00A8 as temporary zp workspace, so stack the existing values.
            LDA L00A8
            PHA
            LDA L00A9
            PHA
            LDA #&00 ; SFTODO: LO(shadowStart)?
            STA L00A8
            LDA #&30 ; SFTODO: HI(shadowStart)?
            STA L00A9
            LDY #&00
.LBC66      LDA (L00A8),Y
            TAX
            LDA romselCopy
            EOR #romselMemsel ; SFTODO: Why not just AND #romselMemsel? We cleared PRVEN/MEMSEL above and I can't see any other entries to this code (e.g. via LBC66) To be fair this code is fine and maybe it is clearer to think of repeatedly flipping than setting or clearing.
            STA romselCopy
            STA romsel
            LDA (L00A8),Y
            PHA
            TXA
            STA (L00A8),Y
            LDA romselCopy
            EOR #&80 ; SFTODO: Why not just NOT_AND romselMemsel?
            STA romselCopy
            STA romsel
            PLA
            STA (L00A8),Y
            INY
            BNE LBC66
            INC L00A9
            BPL LBC66
            PLA
            STA L00A9
            PLA
            STA L00A8
            ; Restore the original value of ROMSEL which we stacked above.
            PLA
            STA romselCopy
            STA romsel
.rts
.LBC97      RTS
}

.LBC98      LDA #&00
            STA ramselCopy
            STA ramsel
            LDX #prvOsMode - prv83								;select OSMODE
            JSR readPrivateRam8300X								;read data from Private RAM &83xx (Addr = X, Data = A)
            BEQ LBCF2
            JSR installOSPrintBufStub
            PHP
            SEI
            ; Save the parent values of BYTEV, WORDV, WRCHV and RDCHV at
            ; parentVectorTbl1 and install our handlers at osPrintBuf+n*3 where
            ; n=0 for BYTEV, 1 for WORDV, etc.
            LDX #&00
            LDY #lo(osPrintBuf)
{
.LBCB0      LDA BYTEVL,X
            STA parentVectorTbl1,X
            TYA
            STA BYTEVL,X
            LDA BYTEVH,X
            STA parentVectorTbl1+1,X
            LDA #hi(osPrintBuf)
            STA BYTEVH,X
            INY
            INY
            INY
            INX
            INX
            CPX #&08
            BNE LBCB0
}
            PLP
            JSR initPrintBuffer
            LDA lastBreakType
            BNE LBCF2
            LDX #prvSFTODOMODE - prv83
            JSR readPrivateRam8300X								;read data from Private RAM &83xx (Addr = X, Data = A)
            BPL LBCF2
            LDA #ramselShen								;set Shadow RAM enable bit
            STA ramselCopy								;store at RAMID
            STA ramsel		          					;store at RAMSEL
            LDA vduStatus								;Get VDU status
            ORA #vduStatusShadow							;set bit 4
            STA vduStatus								;save VDU status
            LDA #modeChangeStateNone
            STA modeChangeState
            RTS
			
.LBCF2      LDA #&00								;clear Shadow RAM enable bit
            STA ramselCopy								;store at RAMID
            STA ramsel			          				;store at RAMSEL
            LDA vduStatus								;get VDU status
            NOT_AND vduStatusShadow							;clear bit 4
            STA vduStatus								;save VDU status
            LDA #modeChangeStateNone
            STA modeChangeState
            ; SFTODO: At a casual glance it seems weird we're setting osShadowRamFlag to 1 here, do I have the interpretation of that flag right?
            LDA #&01
            STA osShadowRamFlag
.SFTODOCOMMON1
            JSR PrvEn								;switch in private RAM
            LDA prvSFTODOMODE
            AND #&7F
            STA prvSFTODOMODE
            JMP PrvDis								;switch out private RAM

; SFTODO: This has only one caller
.SFTODOZZ
{
.LBD18      PHP
            SEI
            LDX #&07
.LBD1C      LDA parentVectorTbl1,X
            STA BYTEVL,X
            DEX
            BPL LBD1C
            LDX #&05
.LBD27      LDA parentVectorTbl2,X
            STA INSVL,X
            DEX
            BPL LBD27
            PLP
            ; SFTODO: The next few lines (down to and including JSR PrvDis) could be replaced by JSR SFTODOCOMMON1, I think.
            JSR PrvEn								;switch in private RAM
            LDA prvSFTODOMODE
            AND #&7F
            STA prvSFTODOMODE
            JSR PrvDis								;switch out private RAM
            JSR maybeSwapShadow2
            JMP LBCF2
}

; Page in PRVS8 and PRVS1, returning the previous value of RAMSEL in A.
; SFTODO: From vague memories of other bits of the code, sometimes we do this
; sort of paging in a bit more ad-hocly, without updating &F4/&37F. So we may
; want to note in the comment that this does the paging in
; properly/formally/some other term.
.pageInPrvs81
{
.LBD45      LDA romselCopy
            ORA #romselPrvEn
            STA romselCopy
            STA romsel
            LDA ramselCopy
            PHA
            ORA #ramselPrvs81
            STA ramselCopy
            STA ramsel
            PLA
            RTS
}

.insvHandler
{
.LBD5C	  TSX
            LDA L0102,X ; get original X=buffer number
            CMP #bufNumPrinter
            BEQ isPrinterBuffer
            LDA #ibosINSVIndex
            JMP forwardToParentVectorTblEntry

.isPrinterBuffer
.LBD69      JSR pageInPrvs81
            PHA
            TSX
            JSR checkPrintBufferFull
            BCC insvBufferNotFull
            ; Return to caller with carry set to indicate insertion failed.
            LDA L0107,X ; get original flags
            ORA #flagC
            STA L0107,X ; modify original flags so C is set
            JMP restoreRamselClearPrvenReturnFromVectorHandler

.insvBufferNotFull
.LBD7E      LDA L0108,X ; get original A=character to insert
            JSR staPrintBufferWritePtr
            JSR advancePrintBufferReadPtr
            JSR decrementPrintBufferFree
            ; Return to caller with carry clear to indicate insertion succeeded.
            TSX
            LDA L0107,X ; get original flags
            NOT_AND flagC
            STA L0107,X ; modify original flags so C is clear
            JMP restoreRamselClearPrvenReturnFromVectorHandler
}

; SFTODO: Would it be possible to factor out the common-ish code at the start of
; insvHandler/remvHandler/cnpvHandler to save space?
.remvHandler
{
.LBD96	  TSX
            LDA L0102,X
            CMP #bufNumPrinter
            BEQ LBDA3
            LDA #ibosREMVIndex
            JMP forwardToParentVectorTblEntry
			
.LBDA3      JSR pageInPrvs81
            PHA
            TSX
            JSR checkPrintBufferEmpty
            BCC LBDB8
            ; SFTODO: Some similarity with insvHandler here, could we factor out common code?
            LDA L0107,X ; get original flags
            ORA #flagC
            STA L0107,X ; modify original flags so C is set
            JMP restoreRamselClearPrvenReturnFromVectorHandler

; SFTODO: The following code doesn't make sense, we seem to be returning in Y
; for examine and A for remove, which is the wrong way round. What am I missing?
.LBDB8      LDA L0107,X ; get original flags
            NOT_AND flagC
            STA L0107,X ; modify original flags so C is clear
            JSR ldaPrintBufferReadPtr
            TSX
            PHA ; note this doesn't affect X so our L01xx,X references stay the same
            LDA L0107,X ; get original flags
            AND #flagV
            BNE examineBuffer
            ; V was cleared by the caller, so we're removing a character from
            ; the buffer.
            PLA
            STA L0108,X ; overwrite original A with character read from our buffer
            JSR advancePrintBufferWritePtr
            JSR incrementPrintBufferFree
            JMP restoreRamselClearPrvenReturnFromVectorHandler

.examineBuffer
            ; V was set by the caller, so we're just examining the buffer
            ; without removing anything.
.LBDD9      PLA
            STA L0102,X ; overwrite original Y with character peeked from our buffer
            FALLTHROUGH_TO restoreRamselClearPrvenReturnFromVectorHandler
}

; Restore RAMSEL to the stacked value, clear PRVEN, then return from the vector
; handler.
; SFTODO: Perhaps not the catchiest label name ever...
.restoreRamselClearPrvenReturnFromVectorHandler
{
.LBDDD      PLA
            STA ramselCopy
            STA ramsel
            LDA romselCopy
            NOT_AND romselPrvEn
            STA romselCopy
            STA romsel
            JMP returnFromVectorHandler
}

.cnpvHandler
{
.LBDF0	  TSX
            LDA L0102,X ; get original X=buffer number
            CMP #bufNumPrinter
            BEQ LBDFD
            LDA #ibosCNPVIndex
            JMP forwardToParentVectorTblEntry

.LBDFD      LDA ramselCopy
            PHA
            JSR PrvEn								;switch in private RAM
            TSX
            LDA L0107,X ; get original flags
            AND #flagV
            BEQ cnpvCount
            ; We're purging the buffer.
            LDX #&47
            JSR readPrivateRam8300X								;read data from Private RAM &83xx (Addr = X, Data = A)
            BEQ LBE16
            JSR purgePrintBuffer
.LBE16      JMP restoreRamselClearPrvenReturnFromVectorHandler

.cnpvCount
.LBE19      LDA L0107,X ; get original flags
            AND #flagC
            BNE cnpvCountSpaceLeft
            ; We're counting the entries in the buffer; return them as 16-bit value YX.
            JSR getPrintBufferUsed
            TXA
            TSX
            STA L0103,X ; overwrite stacked X, so we return A to caller in X
            TYA
            STA L0102,X ; overwrite stacked Y, so we return A to caller in Y
            JMP restoreRamselClearPrvenReturnFromVectorHandler
}

.cnpvCountSpaceLeft
{
            ; We're counting the space left in the buffer; return that as 16-bit value YX.
.LBE2F      JSR getPrintBufferFree
            ; SFTODO: Following code is identical to fragment just above, we
            ; could JMP to it to avoid this duplication.
            TXA
            TSX
            STA L0103,X ; overwrite stacked X, so we return A to caller in X
            TYA
            STA L0102,X ; overwrite stacked Y, so we return A to caller in Y
            JMP restoreRamselClearPrvenReturnFromVectorHandler
}

; SFTODO: This only has one caller
; SFTODO: Some of the code in here is similar to that used as part of 'buffer'
; (the *BUFFER command), could it be factored out?
.initPrintBuffer
{
.LBE3E      LDX lastBreakType
            BEQ softBreak
            ; On hard break or power-on reset, set up the printer buffer so it
            ; uses private RAM from prvPrvPrintBufferStart onwards.
            JSR PrvEn								;switch in private RAM
            LDA #&00
            STA prvPrintBufferSizeLow
            STA prvPrintBufferSizeHigh
            STA prvPrintBufferFirstBankIndex
            STA prv82+&0F
            ; SFTODO: Following code is similar to chunk just below L8D5A, could
            ; it be factored out?
            JSR sanitisePrvPrintBufferStart
            STA prvPrintBufferBankStart
            LDA #&B0
            STA prvPrintBufferBankEnd
            SEC
            LDA prvPrintBufferBankEnd
            SBC prvPrintBufferBankStart
            STA prvPrintBufferSizeMid
            LDA romselCopy
            ORA #&40
            STA prvPrintBufferBankList
            LDA #&FF
            STA prv83+&19
            STA prv83+&1A
            STA prv83+&1B
.softBreak
.LBE7B      JSR purgePrintBuffer
            JSR PrvDis								;switch out private RAM
            ; Copy the rom access subroutine used by the printer buffer from ROM into RAM.
            LDY #romRomAccessSubroutineEnd - romRomAccessSubroutine - 1
{
.LBE83      LDA romRomAccessSubroutine,Y
            STA ramRomAccessSubroutine,Y
            DEY
            BPL LBE83
}
            PHP
            SEI
            ; Save the parent values of INSV, REMV and CNPV at
            ; parentVectorTbl2 and install our handlers at osPrintBuf+n*3 where
            ; n=4 for INSV, 5 for REMV and 6 for CNPV.
            LDX #&00
            LDY #lo(osPrintBuf + 4 * 3)
{
.LBE92      LDA INSVL,X
            STA parentVectorTbl2,X
            TYA
            STA INSVL,X
            LDA INSVH,X
            STA parentVectorTbl2+1,X
            LDA #hi(osPrintBuf + 4 * 3)
            STA INSVH,X
            INY
            INY
            INY
            INX
            INX
            CPX #&06
            BNE LBE92
}
            PLP
            RTS
}

{
; Advance prvPrintBufferWritePtr by one, wrapping round at the end of each bank
; and wrapping round at the end of the bank list.
; SFTODO: This has only one caller
.^advancePrintBufferWritePtr
.LBEB2      LDX #&03
            BNE LBEB8 ; always branch
; Advance prvPrintBufferReadPtr by one, wrapping round at the end of each bank
; and wrapping round at the end of the bank list.
; SFTODO: This has only one caller
.^advancePrintBufferReadPtr
.LBEB6      LDX #&00
.LBEB8      INC prvPrintBufferPtrBase,X
            BNE LBEE8
            INC prvPrintBufferPtrBase + 1,X
            LDA prvPrintBufferPtrBase + 1,X
            CMP prvPrintBufferBankEnd
            BCC LBEE8
            LDY prvPrintBufferPtrBase + 2,X
            INY
            CPY #&04
            BCC LBED2
            LDY #&00
.LBED2      LDA prvPrintBufferBankList,Y
            BPL LBED9
            ; Top bit of this bank number is set, so it's going to be $FF
            ; indicating an invalid bank; wrap round to the first bank.
            LDY #&00
.LBED9      TYA
            STA prvPrintBufferPtrBase + 2,X
            ; SFTODO: Are the next two lines redundant? I think we can only get
            ; here if INC prvPrintBufferPtrBase,X above left this value zero.
            LDA #&00
            STA prvPrintBufferPtrBase,X
            LDA prvPrintBufferBankStart
            STA prvPrintBufferPtrBase + 1,X
.LBEE8      RTS
}

; SFTODO: This has only one caller
; Return with carry set if and only if the printer buffer is full.
.checkPrintBufferFull
{
.LBEE9      LDA prvPrintBufferFreeLow
            ORA prvPrintBufferFreeMid
            ORA prvPrintBufferFreeHigh
            BEQ LBEF6
            CLC
            RTS
			
.LBEF6      SEC
            RTS
}

; SFTODO: This has only one caller
; Return with carry set if and only if the printer buffer is empty.
.checkPrintBufferEmpty
{
.LBEF8      LDA prvPrintBufferFreeLow
            CMP prvPrintBufferSizeLow
            BNE LBF12
            LDA prvPrintBufferFreeMid
            CMP prvPrintBufferSizeMid
            BNE LBF12
            LDA prvPrintBufferFreeMid
            CMP prvPrintBufferSizeMid
            BNE LBF12
            SEC
            RTS

; SFTODO: We could share this code with the tail of LBEE9 to save two bytes.
.LBF12      CLC
            RTS
}

; SFTODO: This currently only has one caller, so could be inlined. Although
; maybe there's some critical alignment stuff going on, which means certain code
; has to live in the &Bxxx region so it can be accessed while private RAM is
; paged in. But we could potentially move the caller (or just all INSV/CNPV/REMV
; code??) into &Bxxx, although it may not be worth the hassle.
.getPrintBufferFree
{
.LBF14      LDX prvPrintBufferFreeHigh
            BNE atLeast64KFree
            LDX prvPrintBufferFreeLow
            LDY prvPrintBufferFreeMid
            RTS

.atLeast64KFree
            ; Tell the caller there's 64K-1 byte free, which is the maximum
            ; return value.
            LDX #&FF
            LDY #&FF
            RTS
}

; SFTODO: Currently has only one caller FWIW
.getPrintBufferUsed
{
; SFTODO: Won't this incorrectly return 0 if a 64K buffer is entirely full? Do
; we prevent this happening somehow? This could be tested fairly easily by
; simply having no printer connected/turned on, setting a 64K buffer, writing
; 64K to it and then calling CNPV to query the amount of data in the buffer. It's
; possible the nature of the (presumably) circular print buffer means it can
; never actually contain more than 64K-1 bytes even if it's 64K, but that's
; just speculation.
.LBF25      SEC
            LDA prvPrintBufferSizeLow
            SBC prvPrintBufferFreeLow
            TAX
            LDA prvPrintBufferSizeMid
            SBC prvPrintBufferFreeMid
            TAY
            RTS
}

; SFTODO: This has only a single caller
.incrementPrintBufferFree
{
.LBF35      INC prvPrintBufferFreeLow
            BNE LBF3D
            INC prvPrintBufferFreeMid
.LBF3D      BNE LBF42
            INC prvPrintBufferFreeHigh
.LBF42      RTS
}

; SFTODO: This has only a single caller
.decrementPrintBufferFree
{
.LBF43      SEC
            LDA prvPrintBufferFreeLow
            SBC #&01
            STA prvPrintBufferFreeLow
            LDA prvPrintBufferFreeMid
            SBC #&00
            STA prvPrintBufferFreeMid
            BCS LBF59
            DEC prvPrintBufferFreeHigh
.LBF59      RTS
}

;code relocated to &0380
;this code either reads, writes or compares the contents of ROM Y address &8000 with A
; SFTODO: Both here and with the vector RAM stub, it might be better to use a
; naming convention where the ROM copy is suffixed "Template" and the RAM copy doesn't
; have any special naming. The current naming convention isn't that bad, but when it's
; natural for the name of this subroutine to include "Rom" it gets a little confusing.
ramRomAccessSubroutine = &0380 ; SFTODO: Move this line?
.romRomAccessSubroutine
.LBF5A      LDX romselCopy				;relocates to &0380
            STY romselCopy				;relocates to &0382
            STY romsel			;relocates to &0384
.romRomAccessSubroutineVariableInsn
ramRomAccessSubroutineVariableInsn = ramRomAccessSubroutine + (romRomAccessSubroutineVariableInsn - romRomAccessSubroutine)
	  EQUB &00			;relocates to &0387. Note this byte gets dynamically changed by the code to &AD (LDA &), &8D (STA &) and &CD (CMP &)
	  EQUB $00,$80			;relocates to &0388. So this becomes either LDA &8000, STA &8000 or CMP &8000
            STX romselCopy				;relocates to &038A
            STX romsel			;relocates to &038C
            RTS				;relocates to &038F
.romRomAccessSubroutineEnd

; Temporarily page in ROM bank prvPrintBufferBankList[prvPrintBufferReadBankIndex] and do LDA (prvPrintBufferReadPtr)
; SFTODO: This only has a single caller
.ldaPrintBufferReadPtr
{
.LBF6A      PHA
            LDX #&03
            LDA #opcodeLdaAbs
            BNE LBF76 ; always branch
; Temporarily page in ROM bank prvPrintBufferBankList[prvPrintBufferWriteBankIndex] and do STA (prvPrintBufferWritePtr)
; SFTODO: This only has a single caller
.^staPrintBufferWritePtr
.LBF71      PHA
            LDX #&00
            LDA #opcodeStaAbs
.LBF76      STA ramRomAccessSubroutineVariableInsn
            LDA prvPrintBufferPtrBase,X
            STA ramRomAccessSubroutineVariableInsn + 1
            LDA prvPrintBufferPtrBase + 1,X
            STA ramRomAccessSubroutineVariableInsn + 2
            LDY prvPrintBufferPtrBase + 2,X
            LDA prvPrintBufferBankList,Y
            TAY
            PLA
            JMP ramRomAccessSubroutine
}

.purgePrintBuffer
{
.LBF90      LDA #&00
            STA prvPrintBufferWritePtr
            STA prvPrintBufferReadPtr
            LDA prvPrintBufferBankStart
            STA prvPrintBufferWritePtr + 1
            STA prvPrintBufferReadPtr + 1
            LDA prvPrintBufferFirstBankIndex
            STA prvPrintBufferWriteBankIndex
            STA prvPrintBufferReadBankIndex
            LDA prvPrintBufferSizeLow
            STA prvPrintBufferFreeLow
            LDA prvPrintBufferSizeMid
            STA prvPrintBufferFreeMid
            LDA prvPrintBufferSizeHigh
            STA prvPrintBufferFreeHigh
            RTS
}

; If prvPrvPrintBufferStart isn't in the range &90-&AC, set it to &AC. We return with prvPrvPrintBufferStart in A.
.sanitisePrvPrintBufferStart
{
.LBFBD      LDX #prvPrvPrintBufferStart-prv83                                                                   ; SFTODO: not too happy with this format
            JSR readPrivateRam8300X							;read data from Private RAM &83xx (Addr = X, Data = A)
            CMP #&90
            BCC LBFCA
            CMP #&AC
            ; SFTODO: We could BCC to a *different* RTS (there's one just above)
            ; and make the JSR:RTS below into a JMP, saving a byte.
            BCC LBFCF
.LBFCA      LDA #&AC
            JSR writePrivateRam8300X								;write data to Private RAM &83xx (Addr = X, Data = A)
.LBFCF      RTS
}

			EQUB &00,$00,$00,$00,$00,$00,$00,$00
			EQUB &00,$00,$00,$00,$00,$00,$00,$00
			EQUB &00,$00,$00,$00,$00,$00,$00,$00
			EQUB &00,$00,$00,$00,$00,$00,$00,$00
			EQUB &00,$00,$00,$00,$00,$00,$00,$00
			EQUB &00,$00,$00,$00,$00,$00,$00,$00
.end

SAVE "IBOS-01.rom", start, end

; SFTODO: Would it be possible to save space by factoring out "LDX #prvOsMode:JSR
; readPrivateRam8300X" into a subroutine?

; SFTODO: Could we save space by factoring out some common-ish sequences of code
; to set or clear various bits of ROMSEL/RAMSEL and their RAM copies?

; SFTODO: Eventually it might be good to get rid of all the Lxxxx address
; labels, but I'm keeping them around for now as they might come in handy and
; it's much easier to take them out than to put them back in...

; SFTODO: The original ROM obviously has everything aligned correctly, but if
; we're going to be modifying this in the future it might be good to put
; asserts in routines which have to live outside a certain area of the ROM in
; order to avoid breaking when we page in private RAM.

; SFTODO: I've been wrapping my multi-line comments to 80 characters (when I
; remember!), it might be nice to tweak the final disassembly to fit entirely in
; 80 columns.

; SFTODO: Enhancement idea - allow "*CO." as an abbreviation for *CONFIGURE. The
; Master accepts this, and it does trip me up when using IBOS.
