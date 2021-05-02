; Terminology:
; - "private RAM" is the 12K of RAM which can be paged in via PRVEN+PRVS1/4/8 in
;   the &8000-&AFFF region
; - "shadow RAM" is the 20K of RAM which can be paged in via SHEN+MEMSEL in the
;   &3000-&7FFF region

; Some all-caps keywords are used in comments to make it easier to find them later:
;
; TODO/SFTODO: General purpose "something needs attention" comments
;
; SQUASH: There's a potential code squashing opportunity here, i.e. an opportunity to shrink
; the code without affecting its functionality.
;
; DELETE: Code which does something but not necessarily something all that useful, which might
; be a candidate for removal if we're desperate for space later. Some such code might
; alternatively be expanded into a more complete feature instead of deleting it.
;
; ENHANCE: An idea for a possible enhancement in a future version of IBOS.

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
;&29:	RTC &09 - Year (Set at writeRtcDate)
;&2A:	RTC &08 - Month (Set at writeRtcDate)
;&2B:	RTC &07 - Day of Month (Set at writeRtcDate)
;&2C:	RTC &06 - Day of Week (Set at writeRtcDate)
;&2D:	RTC &04 - Hours (Set at WriteRtcTime)
;&2E:	RTC &02 - Minutes (Set at WriteRtcTime)
;&2F:	RTC &00 - Seconds (Set at WriteRtcTime)
;&52:	
;&53:	

;PRVS1 Address &83xx
;&08..&0B - Stores the absolute RAM bank number for the Pseudo RAM banks W, X, Y, Z
;&0C..&0F - 
;&18..&1B - Used to store the RAM banks that are assigned to *BUFFER. Up to 4 RAM banks can be assigned. Set to &FF if nothing assigned. 
;&2C..&3B - Private RAM Copy of ROM Type
;3C - OSMODE ?


;RTC Clock Registers
;The RTC is a Harris CDP6818; the datasheet can be downloaded from https://datasheetspdf.com/pdf-file/546796/HarrisSemiconductor/CDP6818/1
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
rtcRegSeconds = &00
rtcRegAlarmSeconds = &01
rtcRegMinutes = &02
rtcRegAlarmMinutes = &03
rtcRegHours = &04
rtcRegAlarmHours = &05
rtcRegDayOfWeek = &06
rtcRegDayOfMonth = &07
rtcRegMonth = &08
rtcRegYear = &09
rtcRegA = &0A
	rtcRegADV0 = 1<<4
	rtcRegADV1 = 1<<5
	rtcRegADV2 = 1<<6
	rtcRegAUIP = 1<<7
rtcRegB = &0B
	rtcRegBDSE = 1<<0
	rtcRegB2412 = 1<<1
	rtcRegBDM = 1<<2
	rtcRegBSQWE = 1<<3
	rtcRegBUIE = 1<<4
	rtcRegBAIE = 1<<5
	rtcRegBPIE = 1<<6
	rtcRegBSET = 1<<7
rtcRegC = &0C
	rtcRegCIRQF = 1<<7

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
userRegLangFile = &05 ; b0-3: FILE, b4-7: LANG
userRegBankInsertStatus = &06 ; 2 bytes, 1 bit per bank
userRegModeShadowTV = &0A ; 0-2: MODE / 3: SHADOW / 4: TV interlace / 5-7: TV screen shift
userRegFdriveCaps = &0B ; 0-2: FDRIVE / 3-5: CAPS
userRegKeyboardDelay = &0C ; 0-7: Keyboard delay
userRegKeyboardRepeat = &0D ; 0-7: Keyboard repeat
userRegPrinterIgnore = &0E ; 0-7: Printer ignore
userRegTubeBaudPrinter = &0F  ; 0: Tube / 2-4: Baud / 5-7: Printer
userRegDiscNetBootData = &10 ; 0: File system disc/net flag / 4: Boot / 5-7: Data
userRegOsModeShx = &32 ; b0-2: OSMODE / b3: SHX / b4: automatic daylight saving time adjust SFTODO: Should rename this now we've discovered b4
; SFTODO: b4 of userRegOsModeShx doesn't seem to be exposed via *CONFIGURE/*STATUS - should it be? Might be interesting to try setting this bit manually and seeing if it works. If it's not going to be exposed we could save some code by deleting the support for it.
userRegAlarm = &33 ; SFTODO? bits 0-5??
userRegCentury = &35
userRegHorzTV = &36 ; "horizontal *TV" settings
userRegBankWriteProtectStatus = &38 ; 2 bytes, 1 bit per bank
userRegPrvPrintBufferStart = &3A ; the first page in private RAM reserved for the printer buffer (&90-&AC)
userRegRamPresenceFlags = &7F ; b0 set=RAM in banks 0-1, b1 set=RAM in banks 2-3, ...

; SFTODO: Very temporary variable names, this transient workspace will have several different uses on different code paths. These are for osword 42, the names are short for my convenience in typing as I introduce them gradually but they should be tidied up later.
; SFTODO: I am thinking these names - maybe now, and probably also in "final" vsn - should have the actual address as part of the name - because different bits of code use the same location for different things, this will help to make it a bit more obvious if two bits of code are trying to use the same location for two different purposes at once (mainly important when we come to modify the code, but just might be relevant if there are bugs in the existing code)
transientOs4243SwrAddr = &A8 ; 2 bytes
transientFileHandle = &A8 ; 1 byte
transientOs4243MainAddr = &AA ; 2 bytes
transientOs4243SFTODO = &AC ; 2 bytes
; SFTODO: &AC/&AD IS USED FOR ANOTHER 16-BIT WORD, SEE adjustTransferParameters
transientOs4243BytesToTransfer = &AE ; 2 bytes
transientRomBankMask = &AE ; 2 bytes SFTODO: Rename this "set" or something instead of "mask"???

transientCmdPtr = &A8 ; 2 bytes
transientTblPtr = &AA ; 2 bytes
transientCmdIdx = &AA ; 1 byte SFTODO: as in other places, this is "cmd" in the sense that one of our * commands or one of our *CONFIGUURE X "things" is a "command", not *just* * commands
transientDynamicSyntaxState = &AE ; 1 byte
; SFTODO: Named constants for b7 and b6
transientDynamicSyntaxStateCountMask = %00111111

transientDateBufferPtr = &A8 ; SFTODO!?
transientDateBufferIndex = &AA ; SFTODO!?
transientDateSFTODO2 = &AA ; SFTODO: prob just temp storage
transientDateSFTODO1 = &AB ; SFTODO!? 2 bytes?

FilingSystemWorkspace = &B0; IBOS repurposes this, which feels a bit risky but presumably works in practice

ConvertIntegerResult = FilingSystemWorkspace ; 4 bytes

vduStatus = &D0
vduStatusShadow = &10
vduGraphicsCharacterCell = &D6 ; 2 bytes
romActiveLastBrk = &024A
negativeVduQueueSize = &026A
tubePresenceFlag = &027A ; SFTODO: allmem says 0=inactive, is there actually a specific bit or value for active? what does this code rely on?
osShadowRamFlag = &027F ; *SHADOW option, 1=force shadow mode, 0=don't force shadow mode
currentLanguageRom = &028C ; SFTODO: not sure yet if we're using this for what the OS does or repurposing it
currentMode = &0355

romTypeTable = &02A1
romPrivateWorkspaceTable = &0DF0

romTypeSrData = 2 ; ROM type byte used for banks allocated to pseudo-addressing via *SRDATA

osBrkStackPointer = &F0
osCmdPtr = &F2
osErrorPtr = &FD
osRdRmPtr = &F6

osfindClose = &00
osfindOpenInput = &40
osfindOpenOutput = &80
osfindOpenUpdate = &C0
osgbpbReadCurPtr = &04
osfileReadInformation = &05
osfileReadInformationLengthOffset = &0A
osfileLoad = &FF

keycodeAt = &47 ; internal keycode for "@"
keycodeNone = &FF ; internal keycode returned if no key is pressed

osargsReadFilingSystemNumber = 0

osbyteSetPrinterType = &05
osbyteSetPrinterIgnore = &06
osbyteSetSerialReceiveRate = &07
osbyteSetSerialTransmitRate = &08
osbyteSetAutoRepeatDelay = &0B
osbyteSetAutoRepeatPeriod = &0C
osbyteFlushSelectedBuffer = &15
osbyteKeyboardScanFrom10 = &7A
osbyteAcknowledgeEscape = &7E
osbyteCheckEOF = &7F
osbyteReadHimem = &84
osbyteEnterLanguage = &8E
osbyteIssueServiceRequest = &8F
osbyteTV = &90
osbyteReadWriteOshwm = &B4
osbyteWriteSheila = &97
osbyteExamineBufferStatus = &98
osbyteReadWriteAciaRegister = &9C
osbyteReadWriteBreakEscapeEffect = &C8
osbyteReadWriteKeyboardStatus = &CA
osbyteEnableDisableStartupMessage = &D7
osbyteReadWriteVduQueueLength = &DA
osbyteReadWriteStartupOptions = &FF

oswordInputLine = &00

romBinaryVersion = &8008

oswdbtA = &EF
oswdbtX = &F0
oswdbtY = &F1

; SFTODO: These may need renaming, or they may not be as general as I am assuming
KeywordTableOffset = 6
CmdTblParOffset = 8
CmdTblPtrOffset = 10

; This is a byte of unused CFS/RFS workspace which IBOS repurposes to track
; state during mode changes. This is probably done because it's quicker than
; paging in private RAM; OSWRCH is relatively performance sensitive and we check
; this on every call.
ModeChangeState = &03A5
ModeChangeStateNone = 0 ; no mode change in progress
ModeChangeStateSeenVduSetMode = 1 ; we've seen VDU 22, we're waiting for mode byte
ModeChangeStateEnteringShadowMode = 2 ; we're changing into a shadow mode
ModeChangeStateEnteringNonShadowMode = 3 ; we're changing into a non-shadow mode

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
transientConfigPrefixSFTODO = &BD; SFTODO: I suspect these uses aren't the same as previous one and should be renamed - I haven't necessarily found all cases where this versino is being used - I think this version is used to hold a config value read from a user register
transientConfigBitMask = &BC

vduBell = 7
vduTab = 9
vduCls = 12
vduCr = 13
vduSetMode = 22
vduDel = 127

maxMode = 7 ; SFTODO!?
shadowModeOffset = &80 ; SFTODO!?

maxBank = 15 ; SFTODO!?

lastBreakType = &028D ; 0=soft reset, 1=power on reset, 2=hard reset SFTODO: named constants?

serviceSelectFilingSystem = &12
serviceConfigure = &28
serviceStatus = &29
serviceAboutToEnterLanguage = &2A
serviceUpdateEnded = &49 ; New IBOS service call to tell sideways ROMs about RTC update cycles

INSVH       = &022B
INSVL       = &022A
KEYVH       = &0229
KEYVL       = &0228
BYTEVH      = &020B
BYTEVL      = &020A
BRKVH       = &0203
BRKVL       = &0202

XKEYV       = &0DDB
XKEYVBank   = XKEYV + 2

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

rtcAddress = SHEILA + &38
rtcData = SHEILA + &3C

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
L03A4       = &03A4 ; SFTODO: This is "GXR flag byte" according to allmem, we seem to be reusing it
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

prvBootSFTODO = prv81 ; SFTODO: Rename this once I've been over the code and I know *exactly* what lives at this address

; The printer buffer is implemented using two "extended pointers" - one for
; reading, one for writing. Each consists of a two byte address and a one byte
; index to a bank in prvPrintBufferBankList; note that these addresses are
; physical addresses in the &8000-&BFFF region, not logical offsets from the
; start of the printer buffer. The two pointers are adjacent in memory and some
; code (using prvPrintBufferPtrBase) will operate on either, using X to specify
; the read pointer (0) or the write pointer (3).
prvPrintBufferPtrBase = prv82 + &00
prvPrintBufferWritePtrIndex = 0
prvPrintBufferWritePtr = prv82 + prvPrintBufferWritePtrIndex
prvPrintBufferWriteBankIndex = prv82 + prvPrintBufferWritePtrIndex + 2
prvPrintBufferReadPtrIndex = 3
prvPrintBufferReadPtr = prv82 + prvPrintBufferReadPtrIndex
prvPrintBufferReadBankIndex = prv82 + prvPrintBufferReadPtrIndex + 2
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
; prvPrintBufferBankCount seems to be the number of banks of sideways RAM allocated to the
; printer buffer; it's 0 if there's no buffer or the buffer is in private RAM.
; SQUASH: This seems to be write-only.
prvPrintBufferBankCount = prv82 + &0F
; prvPrintBufferBankList is a 4 byte list of private/sideways RAM banks used by
; the printer buffer. If there are less than 4 banks, the unused entries will be
; &FF. If the buffer is in private RAM, the first entry will be &4X where X is
; the IBOS ROM bank number and the others will be &FF.
prvPrintBufferBankList  = prv83 + &18 ; 4 bytes
prvPrvPrintBufferStart = prv83 + &45 ; working copy of userRegPrvPrintBufferStart
prvPrintBufferPurgeOption = prv83 + &47 ; &FF for *PURGE ON, &00 for *PURGE OFF

; SFTODO: I believe we do this copy because we want to swizzle it and we mustn't corrupt the user's version, but wait until I've examined more code before writing permanent comment to that effect
prvOswordBlockCopy = prv82 + &20 ; 16 bytes, used for copy of OSWORD &42/&43 parameter block
prvOswordBlockCopySize = 16
; SFTODO: Split prvOswordBlockOrigAddr into two addresses prvOswordX and prvOswordY? Might better reflect how code uses it, not sure yet.
prvOswordBlockOrigAddr = prv82 + &30 ; 2 bytes, used for address of original OSWORD &42/&43 parameter block

prvInputBuffer = prv80 + 0
prvInputBufferSize = 256
prvDateBuffer = prv80 + 0 ; SFTODO: how big?
prvDateBuffer2 = prv80 + &C8 ; SFTODO: how big? not a great name either

; SFTODO: EXPERIMENTAL LABELS USED BY DATE/CALENDAR CODE
prvDateSFTODO0 = prvOswordBlockCopy ; SFTODO: sometimes - maybe always? - used as flags regarding validation - the meaning of the flags is changed (at least) by dateCalculation so just possibly it would be helpful to give this location a different name depending on which style of flags it contains???
prvDateSFTODO1 = prvOswordBlockCopy + 1 ; SFTODO: Use as a bitfield controlling formatting
prvDateSFTODO1b = prvOswordBlockCopy + 1 ; SFTODO: Use as a copy of "final" transientDateBufferIndex
prvDateSFTODO2 = prvOswordBlockCopy + 2
prvDateSFTODO3 = prvOswordBlockCopy + 3
prvDateSFTODO4 = prvOswordBlockCopy + 4 ; 2 bytes SFTODO!?
prvDateSFTODO6 = prvOswordBlockCopy + 6
prvDateSFTODO7 = prvOswordBlockCopy + 7
; SFTODO: I suspect the following locations are not arbitrary and have some relation to OSWORD &E; if so they may be best renamed to indicate this after, not sure until I've been through all the code
prvDateCentury = prvOswordBlockCopy + 8
prvDateYear = prvOswordBlockCopy + 9
prvDateMonth = prvOswordBlockCopy + 10
prvDateDayOfMonth = prvOswordBlockCopy + 11
prvDateDayOfWeek = prvOswordBlockCopy + 12
prvDateHours = prvOswordBlockCopy + 13
prvDateMinutes = prvOswordBlockCopy + 14
prvDateSeconds = prvOswordBlockCopy + 15

; SFTODO WIP - THERE IS SEEMS TO BE AN EXTRA COPY OF PART OF DATE/TIME "OSWORD" BLOCK MADE HERE - "prv2" PART OF NAME IS REALLY JUST TEMP
prv2Flags = prv82 + &42 ; SFTODO: should have "Date" or something in the name
prv2DateCentury = prv82 + &43
prv2DateYear = prv82 + &44
prv2DateMonth = prv82 + &45
prv2DateDayOfMonth = prv82 + &46
prv2DateDayOfWeek = prv82 + &47
prvTmp6 = prv82 + &48
prvA = prv82 + &4A ; SFTODO: tweak name!
prvB = prv82 + &4B ; SFTODO: tweak name!
prvC = prv82 + &4C ; SFTODO: tweak name!
prvD = prv82 + &4D ; SFTODO: tweak name!
prvDC = prvC ; SFTODO: prvC and prvD together treated as a 16-bit value with high byte in prvD
prvTmp2 = prv82 + &4E
prvTmp3 = prv82 + &4F
prvTmp4 = prv82 + &50
prvTmp5 = prv82 + &51

prvTmp = prv82 + &52 ; 1 byte, SFTODO: seems to be used as scratch space by some code without relying on value being preserved

prvOsMode = prv83 + &3C ; working copy of OSMODE, initialised from relevant bits of userRegOsModeShx in service01
prvShx = prv83 + &3D ; working copy of SHX, initialised from relevant bit of userRegOsModeShx in service01 (&00 on, &FF off)
prvSFTODOTUBE2ISH = prv83 + &40
prvSFTODOTUBEISH = prv83 + &41
prvTubeReleasePending = prv83 + &42 ; used during OSWORD 42; &FF means we have claimed the tube and need to release it at end of transfer, 0 means we don't
; SFTODO: If private RAM is battery backed, could we just keep OSMODE in
; prvOsMode and not bother with the copy in the low bits of userRegOsModeShx?
; That would save some code.
prvRtcUpdateEndedOptions = prv83 + &44
	prvRtcUpdateEndedOptionsGenerateUserEvent = 1<<0
	prvRtcUpdateEndedOptionsGenerateServiceCall = 1<<1

prvIbosBankNumber = prv83 + &00 ; SFTODO: not sure about this, but service01 seems to set this
prvPseudoBankNumbers = prv83 + &08 ; 4 bytes, absolute RAM bank number for the Pseudo RAM banks W, X, Y, Z; SFTODO: may be &FF indicating "no such bank" if SRSET is used?
prvSFTODOFOURBANKS = prv83 + &0C ; 4 bytes, SFTODO: something to do with the pseudo RAM banks I think
prvRomTypeTableCopy = prv83 + &2C ; 16 bytes

prvSFTODOMODE = prv83 + &3F ; SFTODO: this is a screen mode (including a shadow flag in b7), but I'm not sure exactly what screen mode yet - current? *CONFIGUREd? something else?

LDBE6       = &DBE6
LDC16       = &DC16
LF168       = &F168
osEntryOsbyteIssueServiceRequest = &F168 ; start of OSBYTE 143 in OS 1.20
LF16E       = &F16E

bufNumKeyboard = 0
bufNumPrinter = 3 ; OS buffer number for the printer buffer

eventNumUser = 9

opcodeJmpAbsolute = &4C
opcodeJmpIndirect = &6C
opcodeCmpAbs = &CD
opcodeLdaAbs = &AD
opcodeStaAbs = &8D

daysPerWeek = 7
daysPerYear = 365

; SFTODO: Define romselCopy = &F4, romsel = &FE30, ramselCopy = &37F, ramsel =
; &FE34 and use those everywhere instead of the raw hex or SHEILA+&xx we have
; now? SFTODO: Or maybe romId instead of romselCopy and ditto for ramselCopy,
; to match the Integra-B documentation, although I find those names a bit less
; intuitive personally.
crtcHorzTotal = SHEILA + &00
crtcHorzDisplayed = SHEILA + &01
systemViaBase = &40
viaRegisterInterruptEnable = 14

romselPrvEn  = &40
romselMemsel = &80
ramselPrvs8  = &10
ramselPrvs4  = &20
ramselPrvs1  = &40
ramselShen   = &80
ramselPrvs81 = ramselPrvs8 OR ramselPrvs1
ramselPrvs841 = ramselPrvs81 OR ramselPrvs4

; bits in the 6502 flags register (as stacked via PHP)
flagC = &01
flagZ = &02
flagV = &40

; Convenience macro to avoid the annoyance of writing this out every time.
MACRO AND_NOT n
    AND #NOT(n) AND &FF
ENDMACRO

; The following convenience macros only save a couple of lines of code each time
; they're used, but they avoid having extra labels cluttering up the code by
; hiding their internal branches.

; "INCrement if Carry Set" - convenience macro for use when adding an 8-bit
; value to a 16-bit value.
MACRO INCCS x
    BCC NoCarry
    INC x
.NoCarry
ENDMACRO

; "DECrement if Carry Clear" - convenient macro for use when subtracting an
; 8-bit value from a 16-bit value.
MACRO DECCC x
    BCS NoBorrow
    DEC x
.NoBorrow
ENDMACRO

; Convenience macro to increment a 16-bit word.
MACRO INCWORD x
    INC x
    BNE NoCarry
    INC x + 1
.NoCarry
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
.romType
		EQUB &C2								;06: ROM type - Bits 1, 6 & 7 set - Language & Service
.copyrightOffset
		EQUB copyright MOD &100						;07: Copyright offset pointer
		EQUB &FF								;08: Binary version number
.title
		EQUS "IBOS", 0							;09: Title string
		EQUS "1.20"							;xx: Version string
.copyright	EQUS 0, "(C)"							;xx: Copyright symbol
		EQUS " "
.computechStart
		EQUS "Computech"
.computechEnd
		EQUS " 1989", 0						;xx: Copyright message

;Store *Command reference table pointer address in X & Y
.CmdRef		LDX #CmdRef MOD &100
		LDY #CmdRef DIV &100
		RTS
		
		EQUS &20								;Number of * commands. Note SRWE & SRWP are not used SFTODO: I'm not sure this is entirely true - the code at SearchKeywordTable seems to use the 0 byte at the end of CmdTbl to know when to stop, and if I type "*SRWE" on an emulated IBOS 1.20 machine I get a "Bad id" error, suggesting the command is recognised (if not necessarily useful). It is possible some *other* code does use this, I'm *guessing* the *HELP display code uses this in order to keep SRWE and SRWP "secret" (but I haven't looked yet).
		ASSERT P% = CmdRef + KeywordTableOffset
		EQUW CmdTbl							;Start of * command table
		ASSERT P% = CmdRef + CmdTblParOffset
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
.ConfRef
{
    LDX #lo(ConfRef):LDY #hi(ConfRef)
    RTS

.^ConfTbla
    EQUB 17							;Number of *CONFIGURE commands
    ASSERT P% = ConfRef + KeywordTableOffset ; SFTODO: Or is this not as common-with-CmdRef parsing as I imagine?
    EQUW ConfTbl							;Start of *CONFIGURE commands lookup table
    ASSERT P% = ConfRef + CmdTblParOffset
    EQUW ConfParTbl							;Start of *CONFIGURE commands parameter lookup table
	
;*CONFIGURE keyword lookup table
.ConfTbl
    EQUS 5, "FILE"
    EQUS 5, "LANG"
    EQUS 5, "BAUD"
    EQUS 5, "DATA"
    EQUS 7, "FDRIVE"
    EQUS 8, "PRINTER"
    EQUS 7, "IGNORE"
    EQUS 6, "DELAY"
    EQUS 7, "REPEAT"
    EQUS 5, "CAPS"
    EQUS 3, "TV"
    EQUS 5, "MODE"
    EQUS 5, "TUBE"
    EQUS 5, "BOOT"
    EQUS 4, "SHX"
    EQUS 7, "OSMODE"
    EQUS 6, "ALARM"
    EQUB 0

;*CONFIGURE parameters table
.ConfParTbl
t = &80
    ;     n, char 1, 2, ... n-1	   i  ConfTbl entry		fully expanded text
    EQUB  7, t+1, "(D/N)"		;  0  FILE		"<0-15>(D/N)"
    EQUB  5, t+19, "15>"		;  1  LANG		"<0-15>"
    EQUB  6, "<1-8>"		;  2  BAUD          	"<1-8>"
    EQUB  4, t+19, "7>"		;  3  DATA		"<0-7>"
    EQUB  2, t+3			;  4  FDRIVE		"<0-7>"
    EQUB  4, t+19, "4>"		;  5  PRINTER       	"<0-4>"
    EQUB  6, t+19, "255>"		;  6  IGNORE		"<0-255>"
    EQUB  2, t+6			;  7  DELAY		"<0-255>"
    EQUB  2, t+6			;  8  REPEAT		"<0-255>"
    EQUB  7, t+17, t+18, "/SH", t+18	;  9  CAPS		"/NOCAPS/SHCAPS"
    EQUB  6, t+6, ",", t+19, "1>"	; 10  TV			"<0-255>,<0-1>"
    EQUB 14, "(", t+4, "/<128-135>)"	; 11  MODE		"(<0-7>/<128-135>)"
    EQUB  6, t+17, "TUBE"		; 12  TUBE		"/NOTUBE"
    EQUB  6, t+17, "BOOT"		; 13  BOOT		"/NOBOOT"
    EQUB  5, t+17, "SHX"		; 14  SHX			"/NOSHX"
    EQUB  2, t+5			; 15  OSMODE		"<0-4>"
    EQUB  5, t+19, "63>"		; 16  -			"<0-63>"
    EQUB  4, "/NO"			; 17  -			"/NO"
    EQUB  5, "CAPS"			; 18  -			"CAPS"
    EQUB  4, "<0-"			; 19  -			"<0-"
    EQUB  0
}

;Store IBOS Options reference table pointer address in X & Y
.ibosRef
{
    LDX #lo(ibosRef):LDY #hi(ibosRef)
    RTS

    EQUB &04								;Number of IBOS options
    ASSERT P% = ibosRef + KeywordTableOffset
    EQUW ibosTbl							;Start of IBOS options lookup table
    ASSERT P% = ibosRef + CmdTblParOffset
    EQUW ibosParTbl							;Start of IBOS options parameters lookup table (there are no parameters!)
    ; SQUASH: I am not sure we actually need the next pointer, if we make the suggested SQUASH:
    ; change in DynamicSyntaxGenerationForIbosSubTblA.
    ASSERT P% = ibosRef + CmdTblPtrOffset
    EQUW ibosSubTbl							;Start of IBOS sub option reference lookup table

.ibosTbl
    EQUS 4, "RTC"
    EQUS 4, "SYS"
    EQUS 4, "FSX"
    EQUS 5, "SRAM"
    EQUB 0

.ibosParTbl
    ; 1 here is "string length + 1", so string length is 0.
    EQUB 1 ; RTC
    EQUB 1 ; SYS
    EQUB 1 ; FSX
    EQUB 1 ; SRAM
    EQUB 0

.ibosSubTbl
}
    ; Elements 0-3 of ibosSubTbl table correspond to the four entries at ibosTbl.
    ibosSubTblHelpNoArgument = 4
    ibosSubTblConfigureList = 5
    EQUW CmdRef:EQUB &00,&03							;&04 x IBOS/RTC Sub options - from offset &00
    EQUW CmdRef:EQUB &04,&13							;&10 x IBOS/SYS Sub options - from offset &04
    EQUW CmdRef:EQUB &14,&17							;&04 x IBOS/FSX Sub options - from offset &14
    EQUW CmdRef:EQUB &18,&1F							;&08 x IBOS/SRAM Sub options - from offset &18
    EQUW ibosRef:EQUB &00,&03							;&04 x IBOS Options - from offset &00
    EQUW ConfRef:EQUB &00,&10							;&11 x CONFIGURE Parameters - from offset &00

; SFTODO: Get rid of the "sub-" prefix here?
; Search the keyword sub-table of the reference table pointed to by YX (typically initialised
; by calling JSR {CmdRef,ibosRef,ConfRef}) for an entry matching the word starting at
; (transientCmdPtr),A.
;
; On exit:
;     A is preserved
;     C clear => keyword sub-table entry X matched
;                (transientCmdPtr),Y is the first non-space after the matched word
;     C set => no match found
.SearchKeywordTable
{
KeywordLength = L00AC
; SFTODO: There's more than meets the eye to MinimumAbbreviationLength; at least on b-em, IBOS
; 1.20 *does* allow "*ST." for *STATUS and "*BU.?" for "*BUFFER ?", but it doesn't allow
; "*CO." for *CONFIGURE.
MinimumAbbreviationLength = 3 ; including the "." which indicates an abbreviation

    PHA
    ; Add A to transientCmdPtr so we can index from 0 in the following code.
    CLC:ADC transientCmdPtr:STA transientCmdPtr
    INCCS transientCmdPtr + 1
    ; Set transientTblPtr=YX[KeywordTableOffset], i.e. make transientTblPtr point to the
    ; keyword sub-table.
    STX transientTblPtr:STY transientTblPtr + 1
    LDY #KeywordTableOffset:LDA (transientTblPtr),Y:TAX
    INY:LDA (transientTblPtr),Y
    STX transientTblPtr ; SQUASH: could just have stored A above instead of TAX
    STA transientTblPtr + 1
    ; Decrement transientCmdPtr by 1 to compensate for using 1-based Y in the following loop.
    ; SQUASH: Use decrement-by-one technique from http://www.obelisk.me.uk/6502/algorithms.html
    SEC:LDA transientCmdPtr:SBC #1:STA transientCmdPtr
    DECCC transientCmdPtr + 1
    ; Loop over the keyword sub-table comparing each entry with the word on the command line.
    LDX #0 ; index of current keyword in keyword sub-table
    LDY #0 ; index of current character in command line
    LDA (transientTblPtr),Y ; get length of first keyword
.KeywordLoop
    STA KeywordLength
    INY
.CharacterMatchLoop
    LDA (transientCmdPtr),Y
    ; Capitalise A; &60 is '£' but we're really trying to avoid mangling non-alphabetic
    ; characters with the AND here. (In particular, '.' AND &DF is &0E.)
    CMP #&60:BCC NotLowerCase
    AND #&DF
.NotLowerCase
    CMP (transientTblPtr),Y:BNE NotSimpleMatch
    INY:CPY KeywordLength:BEQ Match
    JMP CharacterMatchLoop ; SQUASH: Use "BNE ; always branch"
.NotSimpleMatch ; but it might be an abbreviation
    CMP #'.':BNE NotMatch
    CPY #MinimumAbbreviationLength:BCC NotMatch
    INY
.Match
    ; SFTODO: Note that we don't check for a space or CR following the command, so IBOS will
    ; (arguably incorrectly) recognise things like "*STATUSFILE" as "*STATUS FILE" instead of
    ; not claiming them and allowing lower priority ROMs to match against them. To be fair this
    ; is probably OK, it looks like a Master 128 does the same at least with *SRLOAD, and I
    ; think "*SHADOW1" is relatively conventional.
    ; SFTODO: Possibly related and possibly not - doing "*CREATEME" on (emulated) IBOS 1.20
    ; seems to sometimes do nothing and sometimes generate a pseudo-error, as if the parsing is
    ; going wrong. Changing "ME" for other strings can make a difference.
    JSR findNextCharAfterSpace
    CLC ; indicate "match found" to caller
    BCC CleanUpAndReturn ; always branch
.NotMatch
    INX ; increment keyword index
    ; Add KeywordLength to transientTblPtr to skip to the next keyword.
    CLC:LDA transientTblPtr:ADC KeywordLength:STA transientTblPtr
    INCCS transientTblPtr + 1
    ; Get the length of the next keyword in A; if this is 0 we've hit the end of the keyword
    ; sub-table, otherwise loop round.
    ; SQUASH: Could we just JMP to LDY #0 before KeywordLoop and do the BNE test there too?
    LDY #0:LDA (transientTblPtr),Y:BNE KeywordLoop
    SEC ; indicate "no match found" to caller
.CleanUpAndReturn
    ; Decrement Y and increment transientCmdPtr to compensate. SFTODO: Why bother?
    DEY:INCWORD transientCmdPtr
    PLA
    RTS
}

.DynamicSyntaxGenerationForIbosSubTblA
{
FirstEntry = &A8
LastEntry = &A9

    PHA

    ; SQUASH: The following seems needlessly long-winded; it is probably a legacy of an earlier
    ; version where this didn't just operate on ibosRef (note that some callers redundantly
    ; call "JSR ibosRef" before calling this subroutine). We could rewrite it as:
    ;     ASL A:ASL A:TAY
    ;     LDA ibosSubTbl    ,Y:STA transientTblPtr
    ;     LDA ibosSubTbl + 1,Y:STA transientTblPtr + 1
    ;     LDA ibosSubTbl + 2,Y:STA FirstEntry
    ;     LDA ibosSubTbl + 3,Y:STA LastEntry

    ; Set transientTblPtr = transientTblPtr[CmdTblPtrOffset].
    JSR ibosRef:STX transientTblPtr:STY transientTblPtr + 1
    LDY #CmdTblPtrOffset:LDA (transientTblPtr),Y:TAX
    INY:LDA (transientTblPtr),Y:STA transientTblPtr + 1
    STX transientTblPtr ; SQUASH: Just STA in place of TAX above

    ; Copy the the four bytes starting at ibosSubTbl+4*A-on-entry into transientTblPtr and
    ; FirstEntry/LastEntry.
    PLA:PHA:ASL A:ASL A:TAY ; Set Y = A-on-entry * 4
    LDA (transientTblPtr),Y:PHA
    INY:LDA (transientTblPtr),Y:PHA
    INY:LDA (transientTblPtr),Y:STA FirstEntry
    INY:LDA (transientTblPtr),Y:STA LastEntry
    PLA:STA transientTblPtr + 1
    PLA:STA transientTblPtr

    ; Call DynamicSyntaxGenerationForAUsingYX on the table and for the range of entries
    ; FirstEntry (inclusive) to LastEntry (exclusive). SFTODO: Except the upper bound actually
    ; seems to be inclusive, so what am I missing?
.Loop
    LDX transientTblPtr:LDY transientTblPtr + 1
    LDA FirstEntry
    CLC:CLV:JSR DynamicSyntaxGenerationForAUsingYX
    INC FirstEntry:CMP LastEntry:BCC Loop

    PLA
    RTS
}
			
{
.^CmdRefDynamicSyntaxGenerationForTransientCmdIdx
.L83EC      JSR CmdRef								;get start of *command pointer look up table address X=&26, Y=&80
            JMP common
			
; SFTODO: Use a different local label instead of transientTblPtr in here? I am not sure what would be clearest as still working through code...
.^ConfRefDynamicSyntaxGenerationForTransientCmdIdx
.L83F2      JSR ConfRef
.common     CLC
            BIT rts									;set V
            LDA transientCmdIdx							;set A=transientCmdIdx ready to fall through into DynamicSyntaxGenerationForAUsingYX
	  FALLTHROUGH_TO DynamicSyntaxGenerationForAUsingYX
}

; Generate a syntax message using entry A of the table (e.g. ConfTbl) pointed to by YX.
;
; On entry:
;     C set => build a syntax error on the stack and generate it when a carriage return is output
;     C clear => write output to screen (vduTab jumps to a fixed column for alignment)
;                    V clear => prefix with two spaces and emit parameters
;                    V set => no space prefix, don't emit parameters
.DynamicSyntaxGenerationForAUsingYX
{
.L83FB      PHA									;save A-on-entry
            LDA transientTblPtr + 1
            PHA									;save current contents of &AB
            LDA transientTblPtr
            PHA									;save current contents of &AA again SFTODO: why? is this something to do with being entered at DynamicSyntaxGenerationForAUsingYX?? it seems to make little sense otherwise, as we are going to peek the value pushed at DynamicSyntaxGenerationForAUsingYX using LDA L0103,X below anyway.
            STX transientTblPtr
            STY transientTblPtr + 1							;save start of *command pointer lookup table address to &AA / &AB
            JSR startDynamicSyntaxGeneration

            TSX									;get stack pointer
            LDA L0103,X								;get A saved at DynamicSyntaxGenerationForAUsingYX from stack
            PHA									;and save
            LDY #KeywordTableOffset								;offset for address *command lookup table
            LDA (transientTblPtr),Y
            TAX
            INY
            LDA (transientTblPtr),Y
            TAY									;save start of *command lookup table address to X & Y
            PLA									;recover stack value
            JSR EmitEntryAFromTableYX								;write *command to screen???
            LDA #vduTab
            JSR emitDynamicSyntaxCharacter

            BIT transientDynamicSyntaxState						
            BVS dontEmitParameters

            TSX									;get stack pointer
            LDA L0103,X								;read A-on-entry from stack
            PHA									;and save
            LDY #CmdTblParOffset							;offset for address *command parameters lookup table
            LDA (transientTblPtr),Y
            TAX
            INY
            LDA (transientTblPtr),Y
            TAY									;save start of *command parameters lookup table to X & Y
            PLA									;recover stack value
            JSR EmitEntryAFromTableYX								;write *command parameters to screen???
            LDA #vduCr
            JSR emitDynamicSyntaxCharacter

.dontEmitParameters
            PLA
            STA transientTblPtr
            PLA
            STA transientTblPtr + 1
            PLA
.^rts       RTS
}

; Emit the A-th entry of the string table pointed to by YX, recursively expanding top-bit set
; tokens %1abcdefg as the %0abcdefg-th entry of the same string table.
.EmitEntryAFromTableYX
{
; All this zero page workspace is preserved across calls.
TableEntryPtr = &A8 ; 2 bytes
TableBasePtr = &AA ; 2 bytes
Tmp = &AC

    PHA:TXA:PHA
    LDA TableBasePtr:PHA:LDA TableBasePtr + 1:PHA
    STX TableBasePtr:STY TableBasePtr + 1
    TSX:LDA L0104,X	; get A on entry from stack
    JSR EmitEntryAFromTableTableBasePtr
    PLA:STA TableBasePtr + 1:PLA:STA TableBasePtr
    PLA:TAX:PLA
    RTS

; Like EmitEntryAFromTableYX, but with the table pointed to by TableBasePtr instead of YX.
.EmitEntryAFromTableTableBasePtr
    ; Save everything.
    PHA:TXA:PHA:TYA:PHA
    LDA TableEntryPtr + 1:PHA:LDA TableEntryPtr:PHA
    LDA Tmp:PHA

    ; Make TableEntryPtr point to the (A on entry with bit 7 masked off)-th entry in the table
    ; at TableBasePtr.
    TSX:LDA L0106,X:AND #&7F:STA Tmp
    LDA TableBasePtr:STA TableEntryPtr:LDA TableBasePtr + 1:STA TableEntryPtr + 1
    LDX #0 ; current table entry index
    LDY #0 ; remains fixed during the loop
.AdvanceLoop
    CPX Tmp:BEQ AdvanceLoopDone
    CLC:LDA (TableEntryPtr),Y:ADC TableEntryPtr:STA TableEntryPtr
    LDA TableEntryPtr + 1:ADC #0:STA TableEntryPtr + 1 ; SQUASH: INCCS TableEntryPtr + 1
    INX:BNE AdvanceLoop ; always branch
.AdvanceLoopDone

    ; Emit the table entry at TableEntryPtr, recursing to handle top-bit-set tokens.
    LDA (TableEntryPtr),Y:STA Tmp ; set Tmp = length of string + 1
    ; SQUASH: Could we replace next three instructions with JMP DoneChar? Or even BNE DoneChar,
    ; since length of string plus 1 can't be 0?
    CMP #1:BEQ CharLoopDone ; SFTODO: can this happen? do we have "zero length strings"?
    INY
.CharLoop
    LDA (TableEntryPtr),Y:BPL SimpleCharacter
    JSR EmitEntryAFromTableTableBasePtr ; recurse to handle top-bit-set tokens
    JMP DoneChar
.SimpleCharacter
    JSR emitDynamicSyntaxCharacter
.DoneChar
    INY:CPY Tmp:BNE CharLoop
.CharLoopDone

    ; Restore everything.
    PLA:STA Tmp
    PLA:STA TableEntryPtr:PLA:STA TableEntryPtr + 1
    PLA:TAY:PLA:TAX:PLA
    RTS
}
			
; SFTODO: This has only one caller
.startDynamicSyntaxGeneration ; SFTODO: rename?
{
.L84C1      LDA #&00
            ROR A ; move C on entry into b7 of A
            BVC L84C8
            ORA #&40 ; SFTODO: flagV??
.L84C8      STA transientDynamicSyntaxState ; stash original V (&40, b6) and C (&80, b7) in transientDynamicSyntaxState
            BPL generateToScreen
            LDY #&00
.copyLoop   LDA errorPrefix,Y
            STA L0100,Y
            INY
            CMP #' '
            BNE copyLoop
            TYA
            JMP saveA

.generateToScreen
            BIT transientDynamicSyntaxState
            BVS L84E7
            JSR printSpace								;write ' ' to screen
            JSR printSpace								;write ' ' to screen
.L84E7      LDA #&02
.saveA      ORA transientDynamicSyntaxState
            STA transientDynamicSyntaxState
            RTS

.errorPrefix
        	  EQUB &00,&DC
	  EQUS "Syntax: "
}

.emitDynamicSyntaxCharacter
{
; This is the physical column on screen for *HELP output, which is indented by
; two spaces; for non-indented output we start counting at 2 anyway, so we get
; the same gap but the physical column for the tab will be tabColumn - 2.
tabColumn = 12

.L84F8      BIT transientDynamicSyntaxState
            BPL emitToScreen
	  ; We're emitting to an error message we're building up on the stack.
            PHA
            TXA
            PHA
            TSX
            LDA L0102,X								;get A on entry, i.e. character to emit
            PHA
            LDA transientDynamicSyntaxState
            AND #transientDynamicSyntaxStateCountMask
            TAX
            PLA
            STA L0100,X
            CMP #vduCr
            BNE notCr
            LDA #&00
            STA L0100,X
            JMP L0100
			
.notCr      INC transientDynamicSyntaxState
            PLA
            TAX
            PLA
            RTS
			
.notTab     INC transientDynamicSyntaxState
            JMP OSASCI
			
.emitToScreen
            CMP #vduTab
            BNE notTab
            TXA
            PHA
            LDA transientDynamicSyntaxState
            AND #transientDynamicSyntaxStateCountMask
            TAX
            LDA #' '
.tabLoop    CPX #tabColumn
            BCS atOrPastTabColumn
            JSR OSWRCH
            INX
            BNE tabLoop
.atOrPastTabColumn
            PLA
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

; SFTODO: This skips a single comma if present
.^findNextCharAfterSpaceSkippingComma
.L854D      JSR findNextCharAfterSpace								;find next character. offset stored in Y
            BCS L854B
            LDA (transientCmdPtr),Y
            CMP #','
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
            JSR SearchKeywordTable								;test for valid * command
            BCC runCmd								;branch if found a valid * command
            TAY
            LDA (transientCmdPtr),Y
            AND #&DF								;capitalise
            CMP #'I'								;'I' - All Integra-B commands can be prefixed with 'I' to distinguish from other commands
            BNE L857E								; if not 'I', then test for '*X*' or '*S*' commands
            INY										
            TYA									;so try again, with A=1 and Y=1
            JSR CmdRef								;get start of * command look up table address X=&26, Y=&80
            JSR SearchKeywordTable								;test for valid * command
            BCC runCmd								;branch if found a valid * command

.L8579      LDA #&04 ; SFTODO: redundant? ExitServiceCall immediately does PLA
            JMP ExitServiceCall								;restore service call parameters and exit
			
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
	  ; Record the relevant index at transientCmdIdx for use in generating a syntax error later if necessary.
            LDX L00AC
            STX transientCmdIdx
            LDY L00AD
            RTS
}

;*HELP Service Call
.service09
{
            JSR setTransientCmdPtr
            LDA (transientCmdPtr),Y
            CMP #vduCr
            BNE checkArgument
	  ; This is *HELP with no argument
            LDX #ibosSubTblHelpNoArgument
.showHelpX  TXA
            PHA
            JSR OSNEWL
            LDX #title - romHeader
.titleVersionLoop
            LDA romHeader,X
            BNE printChar
            LDA #' '
.printChar  JSR OSWRCH
            INX
            CPX copyrightOffset
            BNE titleVersionLoop
            JSR OSNEWL
            PLA
            JSR ibosRef ; SFTODO: redundant? DynamicSyntaxGenerationForIbosSubTblA does this itself
            JSR DynamicSyntaxGenerationForIbosSubTblA
            JMP ExitServiceCallIndirect

.checkArgument
	  ; See if the *HELP argument is one of the ones we recognise and show it if it is.
            JSR ibosRef
            LDA #&00
            JSR SearchKeywordTable ; SFTODO: maybe rename this to indicate we're not always searching "commands"?
            BCC showHelpX
.ExitServiceCallIndirect
            JMP ExitServiceCall								;restore service call parameters and exit
}

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
.GenerateSyntaxError
{
.L860E      JSR PrvDis								;switch out private RAM
            LDA L00AA
            JSR CmdRef								;get start of * command look up table address X=&26, Y=&80
            SEC
            JMP DynamicSyntaxGenerationForAUsingYX
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
            BEQ ExitServiceCall								;restore service call parameters and exit
            CMP #&05
            BNE L8635								;Process lookup table if not equal to &05
            ; We're handling service call 5 - unrecognised interrupt; see if the RTC has raised
            ; an interrupt.
            LDX #rtcRegC:JSR ReadRtcRam
            CMP #rtcRegCIRQF:BCC ExitServiceCall
            JMP RtcInterruptHandler

.L8635      LDX #&0B
.L8637      CMP srvCallLU,X
            BEQ L864E
            DEX
            BPL L8637

;restore service call parameters and exit
.^ExitServiceCall   PLA										;restore ROM parameter
            TAY
            PLA										;restore ROM number
            TAX
            PLA										;restore service type
            RTS

.^ExitAndClaimServiceCall
    TSX
    LDA #0:STA L0103,X ; set A=0 when returning to caller
    JMP ExitServiceCall ; SQUASH: BEQ ; always branch

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
            STA osErrorPtr
            PLA
            STA osErrorPtr + 1
            LDY #1
.L8689      LDA (osErrorPtr),Y
            STA L0100,Y								;relocate error text
            BEQ L8693
            INY
            BNE L8689
.L8693      STA L0100								;forced BRK
            JMP L0100
}
			
; Parse "ON" or "OFF" from the command line, returning with C clear if we succeed, in which case A=&FF for ON or 0 for OFF. If parsing fails we return with C set and A=&7F. Flags reflect value in A on exit.
.parseOnOff
{
.L8699      JSR findNextCharAfterSpace							;find next character. offset stored in Y
            LDA (transientCmdPtr),Y
            AND #&DF								;capitalise
            CMP #'O'
            BNE invalid
            INY
            LDA (transientCmdPtr),Y
            AND #&DF								;capitalise
            CMP #'N'
            BNE notOn
            INY
            LDA #&FF
            CLC
            RTS
			
.notOn      CMP #'F'
            BNE invalid
            INY
            LDA (transientCmdPtr),Y
            AND #&DF								;capitalise
            CMP #'F'
            BNE off									;accept "OF" to mean "OFF"
            INY
.off        LDA #&00
            CLC
            RTS
			
.invalid    LDA #&7F
            SEC
            RTS
}

; Print "OFF" if A=0, otherwise print "ON".
.printOnOff
{
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
}
			
;Convert binary number in A to numeric characters and write characters to screen
;C set on entry means left pad to three characters with spaces, clear means no padding. SFTODO: Not sure that's right - see how this is used in "buffer"
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
; probably) and the low byte is in A. SFTODO: Introduce named constants for &B0 in this use
; If we fail to parse successfully, we beep and return with A=0.
; SFTODO: I guess it's an IBOS thing, but that beep seems a bit odd - I think
; this is used for commands implemented on B+/Master like SRLOAD and I don't
; think their SRLOAD will ever beep.
; SFTODO: Use of &Bx zp here seems iffy, this is filing system workspace. Did we
; save it somewhere first? Even so, seems less than ideal - what if an interrupt
; occurs?
; SFTODO: Any chance of shrinking this code using loops to work on the 4-byte values?
{
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
            STA ConvertIntegerResult
            STA ConvertIntegerResult + 1
            STA ConvertIntegerResult + 2
            STA ConvertIntegerResult + 3
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
            LDA ConvertIntegerResult
            STA L00B4
            STX ConvertIntegerResult
            LDX #&00
            LDA ConvertIntegerResult + 1
            STA L00B5
            STX ConvertIntegerResult + 1
            LDA ConvertIntegerResult + 2
            STA L00B6
            STX ConvertIntegerResult + 2
            LDA ConvertIntegerResult + 3
            STA L00B7
            STX ConvertIntegerResult + 3
            LDA base
            LDX #&08
.L878D      LSR A
            BCC L87AD
            PHA
            CLC
            LDA ConvertIntegerResult
            ADC L00B4
            STA ConvertIntegerResult
            LDA ConvertIntegerResult + 1
            ADC L00B5
            STA ConvertIntegerResult + 1
            LDA ConvertIntegerResult + 2
            ADC L00B6
            STA ConvertIntegerResult + 2
            LDA ConvertIntegerResult + 3
            ADC L00B7
            STA ConvertIntegerResult + 3
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
            SBC ConvertIntegerResult
            STA ConvertIntegerResult
            LDA #&00
            SBC ConvertIntegerResult + 1
            STA ConvertIntegerResult + 1
            LDA #&00
            SBC ConvertIntegerResult + 2
            STA ConvertIntegerResult + 2
            LDA #&00
            SBC ConvertIntegerResult + 3
            STA ConvertIntegerResult + 3
.L87EF      CPY firstDigitCmdPtrY
            BEQ L87F8
            CLC
            CLV
            LDA ConvertIntegerResult
            RTS
			
.L87F8      LDA #vduBell
            JSR OSWRCH								;Generate VDU 7 beep
            LDA #&00
            LDY originalCmdPtrY
            SEC
            BIT rts									;set V
.rts        RTS

.L8806      JMP GenerateBadParameter
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
            JSR ReadRtcRam								;Read data from RTC memory location X into A
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
            JSR WriteRtcRam								;Write data from A to RTC memory location X
			
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
            AND #ramselShen
            ORA #ramselPrvs1
            STA ramsel							;retain value of ramselCopy so it can be restored after read / write operation complete
            LDA romselCopy
            ORA #romselPrvEn
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
            BEQ languageEntry								;Jump to confirmed language entry
            RTS										;Not a valid language entry


{
;Set BRK Vector
.^setBrkv
.L88D7      LDA #brkvHandler MOD &100
            STA BRKVL
            LDA #brkvHandler DIV &100
            STA BRKVH
            RTS

;Confirmed language entry point
; SFTODO: Start of this code is same as L8969 - could we save a few bytes by (e.g.) setting osErrorPtr to &8000 here and testing for that in BRKV handler and skipping the error printing code in that case?
.^languageEntry
.L88E2      CLI
            CLD
            LDX #&FF
            TXS
            JSR setBrkv								;Set BRK Vector to &8969
            LDA lastBreakType								;Read current language ROM number
            BNE L88F2
            JMP cmdLoop

.L88F2      LDA #osbyteKeyboardScanFrom10
            JSR OSBYTE								;Perform key scan
            CPX #keycodeAt								;Is the @ key being pressed?
            BEQ atPressed
            JMP cmdLoop
			
.atPressed  LDA #osbyteReadWriteBreakEscapeEffect								;Start of RESET routine
            LDX #&02								;Memory cleared on next reset, ESCAPE disabled
            LDY #&00
            JSR OSBYTE
            LDX #&00								;Write 'System Reset' text to screen
.promptLoop LDA resetPrompt,X
            BEQ promptDone
            JSR OSASCI
            INX
            BNE promptLoop
.promptDone
.releaseAtLoop
	  LDA #osbyteKeyboardScanFrom10
            JSR OSBYTE								;Perform key scan
            CPX #keycodeAt								;Is the @ key being pressed?
            BEQ releaseAtLoop								;Repeat until no longer being pressed
            LDA #osbyteFlushSelectedBuffer
            LDX #bufNumKeyboard
            JSR OSBYTE								;Flush keyboard buffer
            CLI
            JSR OSRDCH								;Read keyboard
            PHA
            LDA #osbyteAcknowledgeEscape
            JSR OSBYTE								;Was ESC pressed?
            PLA
            AND #&DF								;Capitalise
            CMP #'Y'								;Was Y pressed?
            BNE L8943								;No? Clear screen, then NLE
            LDX #(yesStringEnd - yesString) - 1
.yesLoop    LDA yesString,X								;Yes? Write 'Yes' to screen
            JSR OSWRCH
            DEX
            BPL yesLoop
            JMP fullReset								;Initiate Full Reset
			
.L8943      LDA #vduCls
            JSR OSWRCH								;Clear Screen
            JMP nle									;Enter NLE

.yesString  EQUS &0D, "seY"
.yesStringEnd
.resetPrompt
	  EQUS "System Reset", &0D, &0D, "Go (Y/N) ? ", &00

;BRK vector entry point
.brkvHandler
; SFTODO: Use of L0700 in next line is potentially iffy, but I suspect this is used only when we're in NLE when IBOS *is* current language, so that would be fine
inputBuf = &700
.L8969	  LDX #&FF								;Break Vector routine
	  TXS
            CLI
            CLD
	  ; Clear the VDU queue, so (e.g.) the first few characters of output
	  ; aren't swallowed if an error occurred half-way through a VDU 23.
            LDA #osbyteReadWriteVduQueueLength
            LDX #&00
            LDY #&00
            JSR OSBYTE
            LDA #osbyteAcknowledgeEscape
            JSR OSBYTE
            JSR OSNEWL
            LDY #&01
.L8981      LDA (osErrorPtr),Y
            BEQ L898B
            JSR OSWRCH
            INY
            BNE L8981
.L898B      JSR OSNEWL
.cmdLoop    JSR printStar
            JSR readLine
            LDX #lo(inputBuf)
            LDY #hi(inputBuf)
            JSR OSCLI
            JMP cmdLoop
			
.osword0Block
;OSWORD A=&0, Read line from input - Parameter block
	  EQUW inputBuf								;buffer address
	  EQUB &FF								;maximum line length
	  EQUB &20								;minimum acceptable ASCII value
	  EQUB &7E								;maximum acceptable ASCII value
.osword0BlockEnd

; SFTODO: This only has one caller
.printStar
       	  LDA #'*'
            JMP OSWRCH

	  ; SFTODO: Is this necessary? Isn't it legit to call OSWORD 0 with a parameter block in SWR anyway, without copying to main RAM first? I think BASIC does that (check), and if it's good enough for BASIC surely it's good enough for us?
.readLine   LDY #(osword0BlockEnd - osword0Block) - 1
.copyLoop   LDA osword0Block,Y
            STA L0100,Y
            DEY
            BPL copyLoop
            LDA #oswordInputLine
            LDX #lo(L0100)
            LDY #hi(L0100)
            JSR OSWORD
            BCS acknowledgeEscapeAndGenerateErrorIndirect ; SFTODO: could we BCC a nearby RTS and just fall through to acknowledge...?
            RTS

.acknowledgeEscapeAndGenerateErrorIndirect
.L89BF      JMP acknowledgeEscapeAndGenerateError
}

;Start of full reset
; SFTODO: This has only one caller
.fullReset
{
	  ; Zero user registers &00-&32 inclusive, except userRegLangFile which is treated as a special case.
.L89C2      LDX #&32								;Start with register &32
.userRegLoop
	  LDA #&00								;Set to 0
            CPX #userRegLangFile							;Check if register &5 (LANG/FILE parameters)
            BNE notLangFile								;No? Then branch
            LDA romselCopy								;Read current ROM number
            ASL A
            ASL A
            ASL A
            ASL A									;move to upper 4 bits (LANG parameter)
            ORA romselCopy								;Read current ROM number & save to lower 4 bits (FILE parameter)
;	  LDA #&EC								;Force LANG: 14, FILE: 12 in IBOS 1.21 (in place of ORA &F4 in line above)
.notLangFile
	  JSR writeUserReg								;Write to RTC clock User area. X=Addr, A=Data
            DEX
            BPL userRegLoop

fullResetPrv = &2800
            JSR LA790								;Stop Clock and Initialise RTC registers &00 to &0B
            LDX #&00								;Relocate 256 bytes of code to main memory
.copyLoop   LDA fullResetPrvTemplate,X
            STA fullResetPrv,X
            INX
            BNE copyLoop
            JMP fullResetPrv

;This code is relocated from IBOS ROM to RAM starting at &2800
.fullResetPrvTemplate
ptr = &00 ; 2 bytes
.L89E9      LDA romselCopy								;Get current SWR bank number.
            PHA									;Save it
            LDX #maxBank								;Start at SWR bank 15
.zeroSWRLoop
	  STX romselCopy								;Select memory bank
            STX romsel
            LDA #&80								;Start at address &8000
	  JSR zeroPageAUpToC0-fullResetPrvTemplate+fullResetPrv				;Fill bank with &00 (will try both RAM & ROM)
            DEX
            BPL zeroSWRLoop								;Until all RAM banks are wiped.
            LDA #ramselShen OR ramselPrvs841						;Set Private RAM bits (PRVSx) & Shadow RAM Enable (SHEN)
            STA ramselCopy
            STA ramsel
            LDA #romselPrvEn								;Set Private RAM Enable (PRVEN) & Unset Shadow / Main toggle (MEMSEL)
            STA romselCopy
            STA romsel
            LDA #&30								;Start at shadow address &3000
	  JSR zeroPageAUpToC0-fullResetPrvTemplate+fullResetPrv				;Fill shadow and private memory with &00
            LDA #&FF								;Write &FF to PRVS1 &830C..&830F
            STA prvSFTODOFOURBANKS
            STA prvSFTODOFOURBANKS + 1
            STA prvSFTODOFOURBANKS + 2
            STA prvSFTODOFOURBANKS + 3
            LDA #&00								;Unset Private RAM bits (PRVSx) & Shadow RAM Enable (SHEN)
            STA ramselCopy
            STA ramsel
            PLA									;Restore SWR bank
            STA romselCopy
            STA romsel
	  ; SFTODO: I may be misreading this code, but won't it access one double-byte entry *past* intDefaultEnd? Effectively treating PHP:SEI as a pair of bytes &08,&78? (Assuming they fit in the 256 bytes copied to main RAM.) I would have expected to write -2 on the next line not -0. Does user reg &08 get used at all? If it never gets overwritten, we could test this by seeing if it holds &78 after a reset. If I'm right, this will overwrite the 0 we wrote in userRegLoop above.
            LDY #(intDefaultEnd - intDefault) - 0						;Number of entries in lookup table for IntegraB defaults
.L8A2D	  LDX intDefault-fullResetPrvTemplate+fullResetPrv+&00,Y				;address of relocated intDefault table:		(address for data)
	  LDA intDefault-fullResetPrvTemplate+fullResetPrv+&01,Y				;address of relocated intDefault table+1:	(data)
            JSR writeUserReg								;Write IntegraB default value to RTC User RAM
            DEY
            DEY
            BPL L8A2D								;Repeat for all 16 values
	  ; SFTODO: We could just do LDA #&7F:STA systemViaBase + viaRegisterInterruptEnable - we know we're running on the host...
	  ; Simulate a power-on reset
            LDA #osbyteWriteSheila							;Write to SHEILA (&FExx)
            LDX #systemViaBase + viaRegisterInterruptEnable					;Write to SHEILA+&4E (&FE4E)
            LDY #&7F								;Data to be written
            JSR OSBYTE								;Write &7F to SHEILA+&4E (System VIA)
            JMP (RESET)								;Carry out Reset

.zeroPageAUpToC0
       	  STA ptr + 1								;This is relocated address &285D
            LDA #&00								;Start at address &8000 or &3000
            STA ptr	  
            TAY
.zeroLoop   LDA #&00								;Store &00
            STA (ptr),Y
            INY
            BNE zeroLoop
            INC L0000+&01
            LDA L0000+&01
            CMP #&C0
            BNE zeroLoop								;Until address is &C000
            RTS

;lookup table for IntegraB defaults - Address (X) / Data (A)
;Read by code at &8834
;For data at addresses &00-&31, data is stored in RTC RAM at location Addr + &0E (RTC RAM &0E-&3F)
;For data at addresses &32 and above, data is stored in private RAM at location &8300 + Addr OR &80.
.intDefault	EQUB userRegBankInsertStatus,&FF						;*INSERT status for ROMS &0F to &08. Default: &FF (All 8 ROMS enabled)
		EQUB userRegBankInsertStatus + 1,&FF						;*INSERT status for ROMS &07 to &00. Default: &FF (All 8 ROMS enabled)
;		EQUB userRegModeShadowTV,&E7							;0-2: MODE / 3: SHADOW / 4: TV Interlace / 5-7: TV screen shift. Default was &17. Changed to &E7 in IBOS 1.21
;		EQUB userRegModeShadowTV,&20							;0-2: FDRIVE / 3-5: CAPS. Default was &23. Changed to &20 in IBOS 1.21
		EQUB userRegModeShadowTV,&17							;0-2: MODE / 3: SHADOW / 4: TV Interlace / 5-7: TV screen shift.
		EQUB userRegFdriveCaps,&23							;0-2: FDRIVE / 3-5: CAPS.
		EQUB userRegKeyboardDelay,&19							;0-7: Keyboard Delay
		EQUB userRegKeyboardRepeat,&05						;0-7: Keyboard Repeat
		EQUB userRegPrinterIgnore,&0A							;0-7: Printer Ignore
		EQUB userRegTubeBaudPrinter,&2D						;0: Tube / 2-4: BAUD / 5-7: Printer
;		EQUB userRegDiscNetBootData,&A1						;0: File system / 4: Boot / 5-7: Data. Default was &A0. Changed to &A1 in IBOS 1.21
		EQUB userRegDiscNetBootData,&A0						;0: File system / 4: Boot / 5-7: Data.
		EQUB userRegOsModeShx,&04							;0-2: OSMODE / 3: SHX
;		EQUB userRegCentury,20 							;Century - Default was &13 (1900). Changed to &14 (2000) in IBOS 1.21
		EQUB userRegCentury,19 							;Century - Default is &13 (1900)
		EQUB userRegBankWriteProtectStatus,&FF
		EQUB userRegBankWriteProtectStatus + 1,&FF
		EQUB userRegPrvPrintBufferStart,&90
		EQUB userRegRamPresenceFlags,&0F						;Bit set if RAM located in 32k bank. Clear if ROM is located in bank. Default is &0F (lowest 4 x 32k banks).
.intDefaultEnd
	  ASSERT (P% + 2) - fullResetPrvTemplate <= 256 ; SFTODO: +2 because as per above SFTODO I think we actually use an extra entry off the end of this table
}


; SFTODO: THIS IS APPROXIMATELY OSBYTE &6F Aries/Watford Shadow RAM Access
{
.^L8A7B	  PHP
	  SEI
	  JSR PrvEn								;switch in private RAM
            TXA ; SFTODO: Just do STX in next line and avoid this? *Or* maybe rely on the fact we have this value in X to avoid needing to load this later
            STA prv82+&53
            LDA ramselCopy
	  ASSERT ramselShen == &80
            ROL A ; get ramselShen in C
            PHP
            LDA prv82+&53
            AND #%11000000 ; mask off b7 (stack yes/no) and b6 (read/write)
            CMP #&80
            BNE L8A9F ; branch if we're not saving the current RAM state
            PLP
            PHP
            ROR prv83+&3E ; put ramselShen in b7 of prv83+&3E; I suspect the lower bits form the stack (max depth 8, therefore) used by OSBYTE &6F
            LDA prv82+&53
            AND #&41 ; clear b7 (stack=yes) of saved original X now we've deal with pushing to the stack
            STA prv82+&53
.L8A9F      PLP
            LDA #&00
            ROL A ; get ramselShen in low bit of A
            STA prvTmp
            BIT prv82+&53
            BVC L8AB3 ; branch if writing state
            BPL L8AC1 ; branch if no stack operation
	  ; So this is a stack pull operation
            ASL prv83+&3E ; pop stack bit and...
            ROL prv82+&53 ; move it into low bit of our "X"
.L8AB3
	  ; Effectively copy the low bit of "our X" into ramselShen
	  LDA ramselCopy
            ROL A
            ROR prv82+&53
            ROR A
            STA ramselCopy
            STA ramsel
.L8AC1      LDA prvTmp
            TAX
            JSR PrvDis								;switch out private RAM
            PLP
            RTS
}
			
;Unrecognised OSBYTE call - Service call &07
;A, X & Y stored in &EF, &F0 & F1 respecively
.service07  LDX #prvOsMode - prv83								;select OSMODE
            JSR readPrivateRam8300X								;read data from Private RAM &83xx (Addr = X, Data = A)
            CMP #&00								;OSMODE 0?
            BNE osbyte6C								;Branch if OSMODE 1-5
            LDA oswdbtA								;get OSBYTE command
            JMP osbyteA1								;Branch if OSMODE 0 - skip OSBYTE &6C / &72

{
;Test for OSBYTE &6C - Select Shadow/Screen memory for direct access
.^osbyte6C	  LDA oswdbtA								;get OSBYTE command
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
            JMP ExitAndClaimServiceCall								;Exit Service Call
}
			
;Test for OSBYTE &72 - Specify video memory to use on next MODE change (http://beebwiki.mdfs.net/OSBYTE_%2672)
{
.^osbyte72  CMP #&72								;OSBYTE &72 - Specify video memory to use on next MODE change
            BNE osbyteA1
            LDA #&EF								;OSBYTE call - write to &27F
            LDX oswdbtX
            BEQ L8B0F								;if '0' then retain '0'
            LDX #&01								;otherwise set to '1'
.L8B0F      LDY #&00
            JSR OSBYTE								;write to &27F
            STX oswdbtX
            JMP ExitAndClaimServiceCall								;Exit Service Call
}
			
;Test for OSBYTE &A1 - Read configuration RAM/EEPROM
.osbyteA1	  CMP #&A1								;OSBYTE &A1 - Read configuration RAM/EEPROM
            BNE osbyteA2
            PLA
            LDX oswdbtX
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            STA oswdbtY
            PHA
            JMP ExitAndClaimServiceCall								;Exit Service Call
			
;Test for OSBYTE &A2 - Write configuration RAM/EEPROM
.osbyteA2	  CMP #&A2								;OSBYTE &A2 - configuration RAM/EEPROM
            BNE osbyte44
            LDX oswdbtX
            LDA oswdbtY
            JSR writeUserReg								;Write to RTC clock User area. X=Addr, A=Data
            PLA
            LDA oswdbtY
            PHA
            JMP ExitAndClaimServiceCall								;Exit Service Call
			
;Test for OSBYTE &44 - Test sideways RAM presence
.osbyte44	  CMP #&44								;OSBYTE &44 (68) - Test sideways RAM presence
            BNE osbyte45
            JMP osbyte44Internal
			
;Test for OSBYTE &45 (69) - Test PSEUDO/Absolute usage
.osbyte45	  CMP #&45								;OSBYTE &45 (69) - Test PSEUDO/Absolute usage
            BNE osbyte49
            JMP osbyte45Internal
			
;Test for OSBYTE &49 (73) - Integra-B calls
; SFTODO: Rename these labels so we have something like "CheckOsbyte49" for the test and "Osbyte49" for the actual "yes, now do it"? (Not just 49, all of them.)
{
prvRtcUpdateEndedOptionsMask = prvRtcUpdateEndedOptionsGenerateUserEvent OR prvRtcUpdateEndedOptionsGenerateServiceCall

.^osbyte49
    CMP #&49:BEQ osbyte49Internal
    JMP ExitServiceCall
.osbyte49Internal
    ; SQUASH: Could we use X instead of A here? Then we'd already have &49 in A and could avoid
    ; LDA #&49.
    LDA oswdbtX:CMP #&FF:BNE XNeFF
    ; It's X=&FF; test for presence of Integra-B. Return with X=&49 to indicate present.
    LDA #&49:STA oswdbtX
    PLA:LDA romselCopy:AND #maxBank:PHA ; SFTODO: DOCUMENT
    JMP ExitAndClaimServiceCall
.XNeFF
.L8B63
    CMP #&FE:BNE XNeFE
    ; It's X=&FE; SFTODO: WHICH MEANS DO WHAT?
    JSR LB35E
    JMP ExitAndClaimServiceCall
.XNeFE
    ; For reference, the "standard" pattern for OSBYTE calls which modify a subset of bits at a
    ; location is to set the location to (<old value> AND Y) EOR X and return the old value in
    ; X. This code *doesn't* follow this pattern.
    ;
    ; This code does prvRtcUpdateEndedOptions = (((X >> 2) AND prvRtcUpdateEndedOptions) EOR X)
    ; AND %11 and returns the original value of prvRtcUpdateEndedOptions in both X and Y. This
    ; effectively means that if X=%abcd, %ab masks off the bits of prvRtcUpdateEndedOptions of
    ; interest and %cd toggles them, so if %ab == 0 we set prvRtcUpdateEndedOptions to %cd.
    ;
    ; We then set rtcRegBUIE iff prvRtcUpdateEndedOptions is non-0; this enables the RTC update
    ; ended interrupt iff RtcInterruptHandler has something to do when it triggers.
    LDX #prvRtcUpdateEndedOptions - prv83:JSR readPrivateRam8300X
    PHA
    STA oswdbtY
    LDA oswdbtX:LSR A:LSR A
    AND oswdbtY
    EOR oswdbtX
    AND #prvRtcUpdateEndedOptionsMask
    JSR writePrivateRam8300X
    LDX #rtcRegB
    CMP #0
    BNE EnableUpdateEndedInterrupt
    JSR ReadRtcRam
    AND_NOT rtcRegBUIE
    JMP Common
.EnableUpdateEndedInterrupt
    JSR ReadRtcRam
    ORA #rtcRegBUIE
.Common
    JSR WriteRtcRam
    PLA
    STA oswdbtX
    JMP ExitAndClaimServiceCall
}

; SFTODO: Dead code
{
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
            RTS
}

;Unrecognised OSWORD call - Service call &08
{
.^service08 LDA oswdbtA								;read OSWORD call number

; SFTODO: Does IBOS not implement OSWORD &0F to set the date/time? To be fair, it's probably little used - it would be quite rude for most software to do so - and it's potentially a bit fiddly. (Do note that beebwiki lists a function 5 to set from centiseconds since 1900, but this isn't in the Master Reference Manual and so it would be fair enough not to implement that.)
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
			
.service08d JMP ExitServiceCall								;restore service call parameters and exit
}

;*BOOT Command
;The *BOOT parameters are stored in Private RAM at &81xx
;They are copied to *KEY10 (BREAK) and executed on a power on reset
;Checks for ? parameter and prints out details;
;Checks for blank and clears table
{
.^boot      JSR PrvEn								;switch in private RAM
            LDA (transientCmdPtr),Y
            CMP #'?'
            BEQ L8C26								;Print *BOOT parameters
            LDA transientCmdPtr
            STA osCmdPtr
            LDA transientCmdPtr + 1
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
            JMP ExitAndClaimServiceCall								;Exit Service Call
			
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
.L8C39      JMP OSNEWLPrvDisExitAndClaimServiceCall

.L8C3C      CMP #&80
            BCC L8C4C
            PHA
            LDA #'|'
            JSR OSWRCH								;write to screen
            LDA #'!'								;'!'
            JSR OSWRCH								;write to screen
            PLA
.L8C4C      AND #&7F
            CMP #&20
            BCS L8C61
.L8C52      AND #&3F
.L8C54      PHA
            LDA #'|'
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
}

;*PURGE Command
.purge
{
            JSR parseOnOff
            BCC purgeOnOrOff
            LDA (transientCmdPtr),Y
            CMP #'?'
            BNE purgeNow
            JSR CmdRefDynamicSyntaxGenerationForTransientCmdIdx
            LDX #prvPrintBufferPurgeOption - prv83
            JSR readPrivateRam8300X							;read data from Private RAM &83xx (Addr = X, Data = A)
            JMP printOnOffOSNEWLExitSC

.purgeNow   JSR PrvEn 								;switch in private RAM
            JSR purgePrintBuffer
            JMP PrvDisExitAndClaimServiceCall

.purgeOnOrOff
	  LDX #prvPrintBufferPurgeOption - prv83
            JSR writePrivateRam8300X							;write data to Private RAM &83xx (Addr = X, Data = A)
            JMP ExitAndClaimServiceCall								;Exit Service Call
}
			
;*BUFFER Command
; This is a big chunk of fairly self-contained code, so we use two levels of scope instead of
; the usual one to pin down the labels a bit more.
.buffer
{
MaxSwrBanks = 4
TmpBankCount = L00AC
TmpTransientCmdPtrOffset = L00AD
TestAddress = &8000 ; ENHANCE: use romBinaryVersion just to play it safe

    JSR PrvEn
    LDA prvOsMode:BNE NotOsMode0 ; the buffer isn't available in OSMODE 0
    JSR raiseError
    EQUB &80
    EQUS "No Buffer!", &00
.NotOsMode0
    JSR convertIntegerDefaultDecimal:BCC BankCountParsedOK
    LDA (transientCmdPtr),Y
    CMP #'#':BEQ UseUserBankList
    CMP #'?':BNE PrvDisGenerateSyntaxError
    JMP ShowBufferSizeAndLocation
.PrvDisGenerateSyntaxError
    JSR PrvDis
    JMP GenerateSyntaxError

.BankCountParsedOK
{
    CMP #MaxSwrBanks + 1:BCC BankCountInA
    JMP GenerateBadParameter
.BankCountInA
    PHA
    JSR GenerateErrorIfPrinterBufferNotEmpty
    JSR UnassignPrintBufferBanks
    LDX #0 ; count of RAM banks found
    LDY #0 ; bank to test
.BankTestLoop
    JSR TestForEmptySwrInBankY:BCS NotEmptySwr
    TYA:STA prvPrintBufferBankList,X
    INX:CPX #MaxSwrBanks:BEQ MaxBanksFound
.NotEmptySwr
    INY:CPY #maxBank + 1:BNE BankTestLoop
.MaxBanksFound
    PLA:BNE BankCountNot0
    JSR UnassignPrintBufferBanks
    JMP prvPrintBufferBankListInitialised
.BankCountNot0
    TAX
    LDA #&FF ; SFTODO: named constant for this (in lots of places)?
.DisableUnwantedBankLoop
    CPX #MaxSwrBanks:BCS prvPrintBufferBankListInitialised
    STA prvPrintBufferBankList,X
    INX:BNE DisableUnwantedBankLoop ; always branch
.prvPrintBufferBankListInitialised
    JSR InitialiseBuffer
    JMP ShowBufferSizeAndLocation
}

; ENHANCE: It's probably more trouble than it's worth, but at the moment something like
; "*BUFFER # 4,4,4,4" will set up a "64K" buffer using bank 4 four times, which probably
; doesn't work out very well; ideally we'd generate an error in this case, or at least
; de-duplicate the list (perhaps using a bank bitmap as we parse) so we'd end up with a 16K
; buffer in this example.
.UseUserBankList
{
    JSR GenerateErrorIfPrinterBufferNotEmpty
    JSR UnassignPrintBufferBanks
    INY
    LDX #0:STX TmpBankCount
.ParseUserBankListLoop
    JSR parseBankNumber:STY TmpTransientCmdPtrOffset
    BCS prvPrintBufferBankListInitialised2 ; stop parsing if bank number is invalid
    TAY:JSR TestForEmptySwrInBankY:TYA:BCS NotEmptySwrBank
    ; SQUASH: INC TmpBankCount:LDX TmpBankCount:STA prvPrintBufferBankList-1,X:...:CPX
    ; #MaxSwrBanks+1? Or initialise TmpBankCount to &FF?
    LDX TmpBankCount:STA prvPrintBufferBankList,X:INX:STX TmpBankCount
    CPX #MaxSwrBanks:BEQ prvPrintBufferBankListInitialised2
.NotEmptySwrBank
    LDY TmpTransientCmdPtrOffset
    JMP ParseUserBankListLoop

    ; SQUASH: This code is identical to prvPrintBufferBankListInitialised above, so we could
    ; just share it; we don't even fall through into it, so the label just needs moving.
.prvPrintBufferBankListInitialised2
    JSR InitialiseBuffer
    JMP ShowBufferSizeAndLocation
}

; SQUASH: Could we use this in some other places where we're initialising
; prvPrintBufferBankList? Even if we called this first and then overwrote the first entry it
; would potentially still save code.
.UnassignPrintBufferBanks
    LDA #&FF
    STA prvPrintBufferBankList
    STA prvPrintBufferBankList + 1
    STA prvPrintBufferBankList + 2
    STA prvPrintBufferBankList + 3
    RTS

{
.UsePrivateRam
    ; SQUASH: "JSR UnassignPrintBufferBanks" here, then delete the LDA #&FF:STA... below?
    LDA romselCopy:AND #maxBank:ORA #romselPrvEn:STA prvPrintBufferBankList
    LDA #&FF
    STA prvPrintBufferBankList + 1
    STA prvPrintBufferBankList + 2
    STA prvPrintBufferBankList + 3
.^InitialiseBuffer
    LDA prvPrintBufferBankList:CMP #&FF:BEQ UsePrivateRam
    AND #&F0:CMP #romselPrvEn:BNE BufferInSwr1 ; SFTODO: magic
    ; Buffer is in private RAM, not sideways RAM.
    JSR SanitisePrvPrintBufferStart:STA prvPrintBufferBankStart
    LDA #&B0:STA prvPrintBufferBankEnd ; SFTODO: mildly magic
    LDA #0
    STA prvPrintBufferFirstBankIndex
    STA prvPrintBufferBankCount
    STA prvPrintBufferSizeLow
    STA prvPrintBufferSizeHigh
    SEC:LDA prvPrintBufferBankEnd:SBC prvPrintBufferBankStart:STA prvPrintBufferSizeMid
    JMP purgePrintBuffer

.BufferInSwr1
    LDA #0
    STA prvPrintBufferSizeLow
    STA prvPrintBufferSizeMid
    STA prvPrintBufferSizeHigh
    TAX
.CountBankLoop
    LDA prvPrintBufferBankList,X:BMI AllBanksCounted
    CLC:LDA prvPrintBufferSizeMid:ADC #&40:STA prvPrintBufferSizeMid ; SFTODO: mildly magic
    ; SQUASH: INCCS prvprintBufferSizeHigh
    LDA prvPrintBufferSizeHigh:ADC #0:STA prvPrintBufferSizeHigh
    INX:CPX #MaxSwrBanks:BNE CountBankLoop
    DEX
.AllBanksCounted
    LDA #&80:STA prvPrintBufferBankStart ; SFTODO: mildly magic
    LDA #0:STA prvPrintBufferFirstBankIndex
    LDA #&C0:STA prvPrintBufferBankEnd ; SFTODO: mildly magic
    STX prvPrintBufferBankCount
    JMP purgePrintBuffer
}
			
.ShowBufferSizeAndLocation
{
    ; Divide high and mid bytes of prvPrintBufferSize by 4 to get kilobytes.
    LDA prvPrintBufferSizeHigh:LSR A
    LDA prvPrintBufferSizeMid:ROR A:ROR A
    SEC:JSR printADecimal
    LDA prvPrintBufferBankList:AND #&F0:CMP #&40:BNE BufferInSwr2 ; SFTODO: magic constants
    LDX #0:JSR PrintKInPrivateOrSidewaysRAM ; write 'k in Private RAM'
    JMP OSNEWLPrvDisExitAndClaimServiceCall
			
.BufferInSwr2
    LDX #1:JSR PrintKInPrivateOrSidewaysRAM ; write 'k in Sideways RAM '
    LDY #0
.ShowBankLoop
    LDA prvPrintBufferBankList,Y:BMI AllBanksShown
    SEC:JSR printADecimal
    LDA #',':JSR OSWRCH
    INY:CPY #MaxSwrBanks:BNE ShowBankLoop
.AllBanksShown
    LDA #vduDel:JSR OSWRCH ; delete the last ',' that was just printed
.*OSNEWLPrvDisExitAndClaimServiceCall
    JSR OSNEWL
.*PrvDisExitAndClaimServiceCall
    JSR PrvDis
    JMP ExitAndClaimServiceCall
}

; Return with C clear iff bank Y is an empty sideways RAM bank. X and Y are preserved.
.TestForEmptySwrInBankY
{
    TXA:PHA
    LDA romTypeTable,Y:BNE NotEmpty
    LDA prvRomTypeTableCopy,Y:BNE NotEmpty
    PHP:SEI
    ; Flip the bits of TestAddress in bank Y and see if the change persists, i.e. if there's
    ; RAM in that bank.
    LDA #lo(TestAddress):STA ramRomAccessSubroutineVariableInsn + 1
    LDA #hi(TestAddress):STA ramRomAccessSubroutineVariableInsn + 2
    LDA #opcodeLdaAbs:STA ramRomAccessSubroutineVariableInsn:JSR ramRomAccessSubroutine:EOR #&FF
    ; SQUASH: We keep stashing A temporarily in X here, but couldn't we just use X to do the
    ; modifications so A is naturally preserved?
    TAX:LDA #opcodeStaAbs:STA ramRomAccessSubroutineVariableInsn:TXA:JSR ramRomAccessSubroutine
    TAX:LDA #opcodeCmpAbs:STA ramRomAccessSubroutineVariableInsn:TXA:JSR ramRomAccessSubroutine
    SEC
    BNE IsRom
    CLC
.IsRom
    TAX
    ; Modify stacked flags to reflect current status of carry.
    ; SQUASH: Could we do ASSERT flagC == 1:PLA:PHP:LSR A:PLP:ROL A:PHA instead of all this?
    PLA:BCS SetStackedCarry
    AND_NOT flagC:PHA
    JMP StackedFlagsModified
.SetStackedCarry
    ORA #flagC:PHA
.StackedFlagsModified
    ; Undo the bit flip of TestAddress so we leave the bank as we found it.
    TXA:EOR #&FF
    ; SQUASH: We are stashing A temporarily in X here, but couldn't we just use X to do the
    ; modifications so A is naturally preserved?
    TAX:LDA #opcodeStaAbs:STA ramRomAccessSubroutineVariableInsn:TXA:JSR ramRomAccessSubroutine
    PLP
    JMP CommonEnd
.NotEmpty
    SEC
.CommonEnd
    PLA:TAX
    RTS
}
}

;Check if printer buffer is empty
.GenerateErrorIfPrinterBufferNotEmpty
{
    PHA:TYA:PHA
    LDA #osbyteExamineBufferStatus:LDX #bufNumPrinter:LDY #0:JSR OSBYTE
    PLA:TAY:PLA
    BCC BufferNotEmpty
    RTS

.BufferNotEmpty
    JSR raiseError ; SFTODO: Change this to "GenerateError", or use "Raise" instead of "Generate" elsewhere
    EQUB &80
    EQUS "Printing!", &00
}

; SQUASH: Since this only has two callers, wouldn't it be easier for them just to do LDX #0 or
; LDX #KInSidewaysRamString - KInPrivateRamString themselves instead of needing to faff with
; the CPX# stuff?
.PrintKInPrivateOrSidewaysRAM
{
    CPX #0:BEQ PrintOffsetXLoop
    LDX #KInSidewaysRamString - KInPrivateRamString
.PrintOffsetXLoop
    LDA KInPrivateRamString,X:BEQ Rts
    JSR OSWRCH
    INX:BNE PrintOffsetXLoop
.Rts
    RTS

.KInPrivateRamString
    EQUS "k in Private RAM", &00
.KInSidewaysRamString
    EQUS "k in Sideways RAM ", &00
}

;*OSMODE Command
.osmode
{
    JSR convertIntegerDefaultDecimal:BCC ParsedOK
    LDA (transientCmdPtr),Y:CMP #'?':BEQ ShowOsMode
    JMP GenerateSyntaxError
.ParsedOK
    JSR SetOsModeA
    JMP ExitAndClaimServiceCall
.ShowOsMode
    JSR CmdRefDynamicSyntaxGenerationForTransientCmdIdx
    LDX #prvOsMode - prv83:JSR readPrivateRam8300X
.^SecPrintADecimalOSNEWLPrvDisExitAndClaimServiceCall
    SEC:JSR printADecimal
    JMP OSNEWLPrvDisExitAndClaimServiceCall
}

.SetOsModeA
{
    CMP #0:BEQ SetOsMode0
    CMP #6:BCS GenerateBadParameterIndirect
    PHA
    JSR PrvEn
    LDA prvOsMode:BEQ CurrentlyInOsMode0
    PLA:STA prvOsMode
.CommonEnd
    ; SQUASH: Couldn't we JMP PrvDis?
    JSR PrvDis
    RTS
			
.GenerateBadParameterIndirect
    JMP GenerateBadParameter

.SetOsMode0
    JSR PrvEn
    LDA prvOsMode:BEQ CommonEnd ; nothing to do as we're already in OSMODE 0
    JSR GenerateErrorIfPrinterBufferNotEmpty
    LDA #0:STA prvOsMode
    JSR EnterOsMode0
    JMP CommonEnd
			
.CurrentlyInOsMode0
    ; We have to check the printer buffer is empty here because OSMODE 0 uses the OS printer
    ; buffer, which will be overwritten by our vector redirection stub in other OSMODEs.
    JSR GenerateErrorIfPrinterBufferNotEmpty
    PLA:STA prvOsMode
    JSR IbosSetUp
    JMP CommonEnd
}
			
;*SHADOW Command
.shadow
{
    JSR convertIntegerDefaultDecimal:BCC ParsedOK
    LDA (transientCmdPtr),Y
    CMP #'?':BEQ ShowShadow
    CMP #vduCr:BNE GenerateSyntaxErrorIndirect2
    LDA #0:JMP ParsedOK ; default to *SHADOW 0 if no argument SQUASH: could BEQ ; always branch
.ShowShadow
    JSR CmdRefDynamicSyntaxGenerationForTransientCmdIdx
    LDA osShadowRamFlag
    JMP SecPrintADecimalOSNEWLPrvDisExitAndClaimServiceCall
.ParsedOK
    STA osShadowRamFlag
    JMP ExitAndClaimServiceCall
}

.GenerateSyntaxErrorIndirect2
    JMP GenerateSyntaxError

;*SHX Command
.shx
{
    JSR parseOnOff:BCC ParsedOK
    LDA (transientCmdPtr),Y:CMP #'?':BNE GenerateSyntaxErrorIndirect2
    JSR CmdRefDynamicSyntaxGenerationForTransientCmdIdx
    LDX #prvShx - prv83:JSR readPrivateRam8300X
    JMP printOnOffOSNEWLExitSC
.ParsedOK
    LDX #prvShx - prv83:JSR writePrivateRam8300X
    JMP ExitAndClaimServiceCall
}

{
;*CSAVE Command
.^csave
    LDA #osfindOpenOutput:JSR parseFilenameAndOpen:TAY
    LDX #0
.SaveLoop
    JSR readUserReg:JSR OSBPUT
    INX:BPL SaveLoop ; write 128 bytes
    BMI CloseAndExit ; always branch

;*CLOAD Command
.^cload
    LDA #osfindOpenInput:JSR parseFilenameAndOpen:TAY
    LDX #0
.LoadLoop
    JSR OSBGET:JSR writeUserReg
    INX:BPL LoadLoop ; read 128 bytes
.CloseAndExit
    JSR CloseTransientFileHandle
    JMP ExitAndClaimServiceCall
}

; SFTODO LINEAR REVIEW UP TO HERE
;*TUBE Command
{
.^tube      JSR parseOnOff
            BCC turnTubeOnOrOff
            LDA (transientCmdPtr),Y
            CMP #'?'
            BNE GenerateSyntaxErrorIndirect
            JSR CmdRefDynamicSyntaxGenerationForTransientCmdIdx
            LDA tubePresenceFlag
.^printOnOffOSNEWLExitSC
.L8FA3      JSR printOnOff
            JSR OSNEWL
.exitSCIndirect
            JMP ExitAndClaimServiceCall								;Exit Service Call

.GenerateSyntaxErrorIndirect
            JMP GenerateSyntaxError

.turnTubeOnOrOff
            BNE turnTubeOn
	  ; Turn the tube off. SFTODO: How? All we seem to do is re-enter the current(ish) language.
            BIT tubePresenceFlag							;check for Tube - &00: not present, &ff: present
            BPL exitSCIndirect							;nothing to do if already off
	  ; SFTODO: We seem to be using currentLanguageRom if b7 clear, otherwise we take the bank number from romsel (which will be our bank, won't it) - not sure what's going on exactly
            LDA currentLanguageRom
            BPL L8FBF
            LDA romselCopy
            AND #maxBank
.L8FBF      PHA
            JSR disableTube
            PLA
            TAX
            JMP doOsbyteEnterLanguage

.^disableTube
.L8FC8      LDA #&00
            LDX #prvSFTODOTUBE2ISH - prv83
            JSR writePrivateRam8300X							;write data to Private RAM &83xx (Addr = X, Data = A)
            LDA #&FF
            LDX #prvSFTODOTUBEISH - prv83
            JSR writePrivateRam8300X							;write data to Private RAM &83xx (Addr = X, Data = A)
            LDA #&00
            STA tubePresenceFlag
            LDA #osargsReadFilingSystemNumber
            LDX #&A8 ; SFTODO: is this relevant?
            LDY #&00 ; handle = 0 for this call
            JSR OSARGS
            TAY
            LDX #serviceSelectFilingSystem
            JSR doOsbyteIssueServiceRequest
            LDA #&00
            LDX #prvSFTODOTUBEISH - prv83
            JMP writePrivateRam8300X							;write data to Private RAM &83xx (Addr = X, Data = A)

.turnTubeOn LDA #&81
            STA SHEILA+&E0
            LDA SHEILA+&E0
            LSR A
            BCS enableTube
            JSR raiseError								;Goto error handling, where calling address is pulled from stack

	  EQUB &80
	  EQUS "No Tube!", &00

;Initialise Tube
; SFTODO: Some code in common with disableTube here (OSARGS/filing system reselection), could factor it out
.enableTube
.L9009      BIT tubePresenceFlag							;check for Tube - &00: not present, &ff: present
            BMI exitSCIndirect							;nothing to do if already on
            LDA #&FF
            LDX #prvSFTODOTUBE2ISH - prv83
            JSR writePrivateRam8300X							;write data to Private RAM &83xx (Addr = X, Data = A)
            LDX #prvSFTODOTUBEISH - prv83
            JSR writePrivateRam8300X							;write data to Private RAM &83xx (Addr = X, Data = A)
            LDX #&FF								;service type &FF - tube system main initialisation
            LDY #&00
            JSR doOsbyteIssueServiceRequest						;issue paged ROM service request
            LDA #&FF
            STA tubePresenceFlag
            LDX #&FE								;service type &FE - tube system post initialisation
            LDY #&00
            JSR doOsbyteIssueServiceRequest						;issue paged ROM service request
            LDA #osargsReadFilingSystemNumber
            LDX #&A8 ; SFTODO: is this relevant?
            LDY #&00 ; handle = 0 for this call
            JSR OSARGS
            TAY
            LDX #serviceSelectFilingSystem
            JSR doOsbyteIssueServiceRequest						;issue paged ROM service request
            LDA #&00
            LDX #prvSFTODOTUBEISH - prv83
            JSR writePrivateRam8300X							;write data to Private RAM &83xx (Addr = X, Data = A)
            LDA #&7F
.L9045      BIT SHEILA+&E2
            BVC L9045
            STA SHEILA+&E3
            JMP L0032

.doOsbyteIssueServiceRequest
            LDA #osbyteIssueServiceRequest						;issue paged ROM service request
            JMP OSBYTE								;execute paged ROM service request
}
			
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
            AND_NOT romselPrvEn                                                                     ;Clear PrvEn
            STA romselCopy
            STA romsel
            LDA ramselCopy
            AND_NOT ramselPrvs1							;Clear PRVS1
            STA ramselCopy
            STA ramsel
            PLA
            RTS
			

{
;execute '*S*' command
;switches to shadow, executes command, then switches back out of shadow?
; SFTODO: Having finally looked at this code properly, that's not really what *S* does; it's a
; bit weird TBH. I don't see why it *couldn't* be the inverse of *X* (although I don't know how
; useful that would be, really), but as written it seems to do *OSMODE 4, *SHADOW 0 (i.e. force
; shadow mode on when changing mode), *SHX OFF, re-select the current screen mode (which will
; therefore be the shadow version, whether it was before or not), disable the tube if enabled
; and then run the command, returning to the caller if we didn't disable the tube and otherwise
; entering the NLE. I am really not sure what's going on - I might *guess* this is an attempt
; to allow a user to "force" shadow RAM to be used by a language ROM (e.g. an early version of
; View) in a simple way, but I'm not sure. Disabling the tube seems particularly odd.
; Particularly as we force SHX OFF (presumably for speed), if you use *S* to do anything other
; than launch a language ROM or new application the running application is likely to be pretty
; confused when it gets control back, which is partly what makes me think this is intended for
; launching languages.
.^commandS
    CLV ; start with V clear, it's set during execution of *S* if we disabled the tube
    SEC:BCS Common ; always branch

;execute '*X*' command
;switches from shadow, executes command, then switches back to shadow
.^commandX
    ; V is irrelevant in this case, unlike commandS.
    CLC
.Common
    PHP
    INY:INY ; skip "S*" or "X*"
    JSR findNextCharAfterSpace
    ; Push the address of the command tail onto the stack ready for CallSubCommand below.
    CLC:TYA:ADC transientCmdPtr:PHA
    LDA transientCmdPtr + 1:ADC #0:PHA
    TSX:LDA L0103,X ; get stacked flags from earlier PHP
    ASSERT flagC == 1:LSR A:BCS SwitchInShadow ; branch if C set in stacked flags
    LDX #&80:JSR L8A7B ; push current RAM state and select video RAM
    JMP CallSubCommand
			
.SwitchInShadow ; SFTODO: Should maybe change this and related labels, since *S* really does "weird stuff"
    LDA #4:JSR SetOsModeA
    LDA #0:STA osShadowRamFlag
    LDX #prvShx - prv83:LDA #&FF:JSR writePrivateRam8300X ; set SHX off SFTODO: magic
    LDA #vduSetMode:JSR OSWRCH:LDA currentMode:JSR OSWRCH
    BIT tubePresenceFlag:BPL NoTube
    JSR disableTube
    TSX:LDA L0103,X:ORA #flagV:STA L0103,X ; set V in stacked flags to indicate tube disabled
    LDA romselCopy:AND #maxBank:STA currentLanguageRom
    JSR setBrkv
.NoTube
.CallSubCommand
    PLA:TAY:PLA:TAX:JSR OSCLI
    PLP
    BCS CheckVAfterSwitchInShadow
    LDX #&C0:JSR L8A7B ; pop and select stacked shadow RAM state
.ExitAndClaimServiceCallIndirect
    JMP ExitAndClaimServiceCall

.CheckVAfterSwitchInShadow
    BVC ExitAndClaimServiceCallIndirect
    FALLTHROUGH_TO nle
}

;*NLE Command
.nle
{
    ; Enter IBOS as a language ROM.
    LDX romselCopy
.^doOsbyteEnterLanguage
    LDA #osbyteEnterLanguage:JMP OSBYTE
}
			
;*GOIO Command
.goio
{
    ; If the argument is wrapped in brackets we treat it as an indirect address; we stash the
    ; flags after doing the first CMP to record whether or not we've seen brackets.
    LDA (transientCmdPtr),Y
    CMP #'(':PHP:BNE NoOpenBracket
    INY
.NoOpenBracket
    JSR convertIntegerDefaultHex:BCC ConvertedOK
    JMP GenerateSyntaxError
.ConvertedOK
    LDA (transientCmdPtr),Y
    CMP #')':BNE NoCloseBracket
    INY
.NoCloseBracket
    JSR findNextCharAfterSpace
    ; Poke a suitable JMP instruction just before the binary address at ConvertIntegerResult.
    LDA #opcodeJmpAbsolute
    PLP:BNE NotIndirect ; use stashed result of earlier CMP #'(' to test for indirect call
    LDA #opcodeJmpIndirect
.NotIndirect
    STA ConvertIntegerResult - 1
    ; Set YX to point to the command tail. SFTODO: Is this an official kind of thing to do?
    CLC:TYA:ADC transientCmdPtr:TAX
    LDA transientCmdPtr + 1:ADC #0:TAY
    LDA #1 ; SFTODO: Why? Is this related to the "A=1 on language entry"? Are we following some sort of standard here?
    JSR ConvertIntegerResult - 1
    JMP ExitAndClaimServiceCall
}
			
;*APPEND Command
.append
{
; SFTODO: Express these as transientWorkspace + n, to document what area of memory they live in?
LineLengthIncludingCr = &A9
LineNumber = &AA
OswordInputLineBlockCopy = &AB ; 5 bytes

    LDA #osfindOpenUpdate:JSR parseFilenameAndOpen
    LDA #0:STA LineNumber
    JSR PrvEn

    ; Start by showing the existing contents of the file we're *APPENDing to.
.ShowLineLoop
    JSR OSNEWL
    LDA #osbyteCheckEOF:LDX transientFileHandle:JSR OSBYTE:CPX #0:BNE Eof
    JSR IncrementAndPrintLineNumber
.ShowCharacterLoop
    LDY transientFileHandle:JSR OSBGET:BCS Eof
    CMP #vduCr:BEQ ShowLineLoop
    ; Don't show control characters.
    CMP #' ':BCC ShowCharacterLoop
    CMP #vduDel:BCS ShowCharacterLoop
    JSR OSWRCH ; flags reflect A on exit
    ; For some reason we treat NUL as starting a new line.
    BNE ShowCharacterLoop
    BEQ ShowLineLoop ; always branch
.Eof

    ; Now accept lines of input from the keyboard and append them to the file until Escape is
    ; pressed.
.AppendLoop
    JSR IncrementAndPrintLineNumber
    ; Copy OswordInputLineBlock into OswordInputLineBlockCopy in main RAM for use.
    ; SQUASH: I don't believe this is necessary, we can just use OswordInputLineBlock directly.
    LDY #(OswordInputLineBlockEnd - OswordInputLineBlock) - 1
.CopyLoop
    LDA OswordInputLineBlock,Y:STA OswordInputLineBlockCopy,Y
    DEY:BPL CopyLoop
    LDX #lo(OswordInputLineBlockCopy):LDY #hi(OswordInputLineBlockCopy)
    LDA #oswordInputLine:JSR OSWORD:BCS Escape
    INY:STY LineLengthIncludingCr
    LDX #0
.AppendCharacterLoop
    LDA prvInputBuffer,X:LDY transientFileHandle:JSR OSBPUT
    CMP #vduCr:BEQ AppendLoop
    INX:CPX LineLengthIncludingCr:BNE AppendCharacterLoop
    BEQ AppendLoop ; always branch

.Escape
    LDA #osbyteAcknowledgeEscape:JSR OSBYTE
    JSR PrvDis
    JSR CloseTransientFileHandle
    JSR OSNEWL
    JMP OSNEWLPrvDisExitAndClaimServiceCall

.OswordInputLineBlock
    EQUW prvInputBuffer
    EQUB prvInputBufferSize - 1 ; maximum length excluding CR
    EQUB ' ' ; minimum acceptable ASCII value
    EQUB '~' ; maximum acceptable ASCII value
.OswordInputLineBlockEnd

.IncrementAndPrintLineNumber
    INC LineNumber
    LDA LineNumber:CLC:JSR printADecimal
    LDA #':':JSR OSWRCH
.^printSpace
    LDA #' ':JMP OSWRCH
}
			
;*PRINT Command
{
.^print      LDA #osfindOpenInput							;open file for input
            JSR parseFilenameAndOpen								;get address of file name and open file
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
            JMP ExitAndClaimServiceCall								;Exit Service Call
			
.L91EE      JSR L9201
.^acknowledgeEscapeAndGenerateError
.L91F1      LDA #osbyteAcknowledgeEscape
            JSR OSBYTE
            JSR raiseError								;Goto error handling, where calling address is pulled from stack

	  EQUB &11
	  EQUS "Escape", &00

.L9201      LDA #&03
            LDX L00A9
            LDY #&00
            JSR OSBYTE
            JMP CloseTransientFileHandle								;close file with file handle at &A8
}
			
;*SPOOLON Command
{
.^spool      LDA #osfindOpenUpdate								;open file for update
            JSR parseFilenameAndOpen								;get address of file name and open file
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
            JMP ExitAndClaimServiceCall								;Exit Service Call
}
			
			
;get start and end offset of file name, store at Y & X
;convert file name offset to address of file name and store at location defined by X & Y
;then open file with file name at location defined by X & Y
.parseFilenameAndOpen
{
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
			
.L9244      STA transientFileHandle								;save file handle to &A8
            RTS									;and return
			
			
;get start and end of file name offset and store in Y & X
.^L9247      JSR findNextCharAfterSpace							;find next character. offset stored in Y
            LDA (transientCmdPtr),Y							;read character
            CMP #vduCr								;CR?
            BNE L9253								;not CR, so jump
.^L9250      JMP GenerateSyntaxError								;no file name, so error with 'Syntax:'

.L9253      TYA
            PHA
.L9255      LDA (transientCmdPtr),Y							;read character
            CMP #' '
            BEQ L9262								;ok. end of file name
            CMP #vduCr								;check for CR
            BEQ L9262								;ok. end of file name
            INY									;otherwise get next character
            BNE L9255								;loop
.L9262      TYA
            TAX
            INX									;end of file name offset
            PLA
            TAY									;start of file name offset
            RTS
}
			
			
;Close file with file handle at &A8
.CloseTransientFileHandle
{
.L9268      LDA #osfindClose
            LDY L00A8
            JMP OSFIND
}
			
;*CREATE Command
{
.^create		JSR L9247
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
            JMP ExitAndClaimServiceCall								;Exit Service Call
}

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
.^GenerateBadParameter
.L92E3      JSR raiseError								;Goto error handling, where calling address is pulled from stack

	  EQUB &FE
	  EQUS "Bad parameter", &00

.exitSCIndirect
            JMP ExitAndClaimServiceCall								;Exit Service Call
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

{
.^L932E      JSR L9337
            JSR ConfRefDynamicSyntaxGenerationForTransientCmdIdx
            JMP OSNEWL
			
.L9337      CMP #&00
            BNE L933C
            RTS

.L933C      CMP #&02								;If &02 then write 'SH' otherwise write 'NO' in front of CAPS
            BEQ L934A
            LDA #'N'
            JSR OSWRCH
            LDA #'O'
            JMP OSWRCH
			
.L934A      LDA #'S'
            JSR OSWRCH
            LDA #'H'
            JMP OSWRCH
}

;*Configure paramters are stored using the following format
;EQUB Register,Start Bit,Number of Bits
ConfParBitUserRegOffset = 0
ConfParBitStartBitOffset = 1
ConfParBitBitCountOffset = 2
.ConfParBit	EQUB userRegLangFile,&00,&04						;FILE ->	  &05 Bits 0..3
		EQUB userRegLangFile,&04,&04						;LANG ->	  &05 Bits 4..7
		EQUB userRegTubeBaudPrinter,&02,&03					;BAUD ->	  &0F Bits 2..4
		EQUB userRegDiscNetBootData,&05,&03					;DATA ->	  &10 Bits 5..7
		EQUB userRegFdriveCaps,&00,&03					;FDRIVE ->  &0B Bits 0..2
		EQUB userRegTubeBaudPrinter,&05,&03					;PRINTER -> &0F Bits 5..7
		EQUB userRegPrinterIgnore,&00,&00					;IGNORE ->  &0E Bits 0..7
		EQUB userRegKeyboardDelay,&00,&00					;DELAY ->	  &0C Bits 0..7
		EQUB userRegKeyboardRepeat,&00,&00					;REPEAT ->  &0D Bits 0..7
		EQUB userRegFdriveCaps,&03,&03					;CAPS ->	  &0B Bits 3..5
		EQUB userRegModeShadowTV,&04,&04					;TV ->	  &0A Bits 4..7
		EQUB userRegModeShadowTV,&00,&04					;MODE ->	  &0A Bits 0..3
		EQUB userRegTubeBaudPrinter,&00,&01					;TUBE ->	  &0F Bit  0
		EQUB userRegDiscNetBootData,&04,&81					;BOOT ->	  &10 Bit  4
		EQUB userRegOsModeShx,&03,&81						;SHX ->	  &32 Bit  3
		EQUB userRegOsModeShx,&00,&03						;OSMODE ->  &32 Bits 0..2
		EQUB userRegAlarm,&00,&06						;ALARM ->	  &33 Bits 0..5

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

; bitMaskTable[X] contains bit mask for an n-bit value; X=0 is used to represent the mask for an 8-bit value.
.bitMaskTable       EQUB &FF,&01,&03,&07
		EQUB &0F,&1F,&3F,&7F


.shiftALeftByX
{
.L93B1      CPX #&00
            BEQ rts
.L93B5      ASL A
            DEX
            BNE L93B5
.rts        RTS
}
IF FALSE
; SFTODO: Saves two bytes, but doesn't guarantee X=0 on return - that may well not matter
.shiftALeftByXAlternate
{
.loop	  DEX
	  BMI rts ; e.g. there's one at L93C2
	  ASL A
	  JMP loop
}
ENDIF

; SFTODO: This only has a single caller
.shiftARightByX
{
.L93BA      CPX #&00
            BEQ L93C2
.L93BE      LSR A
            DEX
            BNE L93BE
.L93C2      RTS
}

.setYToTransientCmdIdxTimes3
{
.L93C3      LDA transientCmdIdx
            ASL A
            ADC transientCmdIdx
            TAY
            RTS
}

.getShiftedBitMask
{
.L93CA      LDA ConfParBit+ConfParBitBitCountOffset,Y
            AND #&7F ; SFTODO: so what does b7 signify?
            TAX
            LDA bitMaskTable,X
            STA transientConfigBitMask ; SFTODO: use PHA?
            LDA ConfParBit+ConfParBitStartBitOffset,Y
            TAX ; SFTODO: we could just do LDX ...,Y in previous instruction, couldn't we?
            LDA transientConfigBitMask ; SFTODO: use PLA?
            JSR shiftALeftByX
            STA transientConfigBitMask
            RTS
}

.setConfigValue
{
.L93E1      STA transientConfigPrefix
.^L93E3     JSR setYToTransientCmdIdxTimes3
            JSR getShiftedBitMask
            LDA ConfParBit+1,Y
            TAX ; SFTODO: LDX blah,Y?
            LDA transientConfigPrefix
            JSR shiftALeftByX
            AND transientConfigBitMask
            STA transientConfigPrefix
            LDA transientConfigBitMask
            EOR #&FF
            STA transientConfigBitMask
            LDA ConfParBit+ConfParBitUserRegOffset,Y
            TAX ; SFTODO: avoid this with LDX blah,Y?
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            AND transientConfigBitMask
            ORA transientConfigPrefix
            JMP writeUserReg							;Write to RTC clock User area. X=Addr, A=Data
}

.getConfigValue
{
.L940A      JSR setYToTransientCmdIdxTimes3
            JSR getShiftedBitMask
            LDA ConfParBit+ConfParBitUserRegOffset,Y
            TAX ; SFTODO: can we just use LDX blah,Y to avoid this?
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            AND transientConfigBitMask
            STA transientConfigPrefixSFTODO ; SFTODO: Just PHA?
            LDA ConfParBit+1,Y
            TAX ; SFTODO: LDX blah,Y
            LDA transientConfigPrefixSFTODO ; SFTODO: Just PLA?
            JSR shiftARightByX
            STA transientConfigPrefixSFTODO
            RTS
}
			
; SFTODO: This code saves transientCmdIdx (&AA) across call to ConfRefDynamicSyntaxGenerationForTransientCmdIdx, but it superficially looks as though ConfRefDynamicSyntaxGenerationForTransientCmdIdx preserves it itself, so the code to preserve here may be redundant.
.printConfigNameAndGetValue ; SFTODO: name is a bit of a guess as I still haven't been through the "dynamic syntax generation" (which is presumably slightly misnamed at least, as at least some of our callers would just want the option name with no other fluff) code properly
{
.L9427      LDA transientCmdIdx
            PHA
            JSR ConfRefDynamicSyntaxGenerationForTransientCmdIdx
            PLA
            STA transientCmdIdx
            JSR getConfigValue
            LDA transientConfigPrefix
            RTS
}

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
            LDA #ibosSubTblConfigureList
            JSR ibosRef ; SFTODO: Redundant? DynamicSyntaxGenerationForIbosSubTblA does JSR ibosRef itself...
            JSR DynamicSyntaxGenerationForIbosSubTblA
            JMP ExitServiceCall								;restore service call parameters and exit
			
.optionSpecified
            LDA #&00
            STA transientConfigPrefix
            JSR ConfRef
            JSR SearchKeywordTable
            BCC optionRecognised
            TAY
            JSR parseNoSh
            BCS notNoSh
            TYA
            JSR ConfRef
            JSR SearchKeywordTable
            BCC optionRecognised
.notNoSh    PLP
            JMP ExitServiceCall								;restore service call parameters and exit
			
.optionRecognised
	  JSR findNextCharAfterSpace							;find next character. offset stored in Y
            PLP
            JSR jmpConfTypTblX
            JMP ExitAndClaimServiceCall								;Exit Service Call
			
; Jump to the code at ConfTypTbl[X]; C is preserved, as it is used to indicate
; *STATUS (clear) or *CONFIGURE (set).
.jmpConfTypTblX
            PHP
            STX transientCmdIdx
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
            JMP ExitServiceCall								;restore service call parameters and exit
}

;Read / Write *CONF. FILE parameters
.Conf0	
{
 	  BCS Conf0Write

;Read *CONF. FILE parameters from RTC register and write to screen
            JSR printConfigNameAndGetValue
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
            JSR printConfigNameAndGetValue
            JMP printADecimalPadNewline
			
.Conf1Write
            JSR convertIntegerDefaultDecimalChecked
            JMP setConfigValue ; SFTODO: move Conf1 block so we can fall through?
}
			
; SFTODO: If we moved this to just before printADecimal we could fall through into it
.printADecimalPad
{
.L94F8      SEC
            JMP printADecimal								;Convert binary number to numeric characters and write characters to screen
}

.printADecimalPadNewline
{
.L94FC      JSR printADecimalPad
            JMP OSNEWL
}
			
.convertIntegerDefaultDecimalChecked
{
.L9502      JSR convertIntegerDefaultDecimal
            BCS GenerateBadParameterIndirect
            RTS
			
.GenerateBadParameterIndirect
            JMP GenerateBadParameter
}


{
.L950B		EQUB &04,&02,&01

.^Conf3	  BCS L9528
            JSR getConfigValue
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
			
.L9528      LDX transientConfigPrefixSFTODO
	  LDA L950B,X
            JMP setConfigValue
}

{
.^Conf6	  BCS Conf6Write
            JSR getConfigValue
            LDA ConfParBit+2,Y
            ASL A
            LDA #&00
            ROL A
            EOR transientConfigPrefixSFTODO
            JMP L932E
			
.Conf6Write JSR setYToTransientCmdIdxTimes3
            LDA ConfParBit+2,Y
            ASL A
            LDA #&00
            ROL A
            EOR transientConfigPrefixSFTODO
            JMP setConfigValue
}

{
.^Conf2     BCS Conf2Write
            JSR getConfigValue
            PHA
            JSR ConfRefDynamicSyntaxGenerationForTransientCmdIdx
            PLA
            CLC
            ADC #&01
            JMP printADecimalPadNewline

.Conf2Write JSR convertIntegerDefaultDecimalChecked
            SEC
            SBC #&01
            JMP setConfigValue
}

{
.^Conf5	  BCS Conf5Write
            JSR getConfigValue
            PHA
            JSR ConfRefDynamicSyntaxGenerationForTransientCmdIdx
            PLA
	  ; Map a "compressed mode" in the range 0-15 to 0-7 or 128-135.
            CMP #maxMode + 1
            BCC modeInA
            ADC #(shadowModeOffset - (maxMode + 1)) - 1 ; -1 because C is set
.modeInA	  JMP printADecimalPadNewline

.Conf5Write JSR convertIntegerDefaultDecimalChecked
	  ; Map a mode 0-7 or 128-135 to a "compressed mode" in the range 0-15.
            CMP #shadowModeOffset
            BCC valueInA
            SBC #shadowModeOffset - (maxMode + 1)
.valueInA   JMP setConfigValue
}

{
.^Conf4	  BCS Conf4Write
            JSR getConfigValue
            PHA
            JSR ConfRefDynamicSyntaxGenerationForTransientCmdIdx
            PLA
            PHA
            LSR A
            CMP #&04
            BCC L959A
            ORA #&F8
.L959A      JSR printADecimalPad
            LDA #','
            JSR OSWRCH
            PLA
            AND #&01
            JMP printADecimalPadNewline

.Conf4Write JSR convertIntegerDefaultDecimalChecked
            AND #&07
            ASL A
            PHA
            JSR findNextCharAfterSpaceSkippingComma
            JSR convertIntegerDefaultDecimalChecked
            AND #&01
            STA L00AE
            PLA
            ORA L00AE
            JMP setConfigValue
}

; SFTODO: This entire block is dead code
{
.L95BF      LDA #&00
            ASL L00AE
            ROL A
            ASL L00AE
            ROL A
            RTS

            JSR L95BF								;Missing address label?
            JSR printADecimalPad
            LDA #','
            JMP OSWRCH
			
            ASL L00AE								;Missing address label?
            ASL L00AE
            JSR findNextCharAfterSpaceSkippingComma
            JSR convertIntegerDefaultDecimalChecked
            AND #&03
            ORA L00AE
            STA L00AE
            RTS
}
			
;Autoboot - Service call &03
.service03
{
	  ; If KEYV is set up to use the extended vector mechanism by a ROM
	  ; which has &47 ("G") at &800D, set romselMemsel on the extended
	  ; vector bank number. SFTODO: I believe this will have the effect of
	  ; ensuring main/video memory is paged in. This seems weird, I am
	  ; guessing it's a workaround for a particular ROM, but I don't know
	  ; what or why. Just *maybe* this is the GXR? (But does that claim
	  ; KEYV?) Just might be worth asking on stardot about this at some
	  ; point. - OK, looking at the Integra-B manual, it does mention GXR
	  ; in the "Applications" section, but I think this is much more likely
	  ; to be for GENIE, which will almost certainly be claiming KEYV to
	  ; allow it to be entered. (I haven't checked GXR or GENIE yet to see
	  ; what is at &800D - OK, I now have, both GENIE 1.01 and GENIE 1.02 have "G" at &800D.)
	  ; SFTODO: Ken - just a random thought, GENIE is PALPROM-ish with extra RAM, would your v2 board maybe be able to run it? Some discussion on stardot https://stardot.org.uk/forums/viewtopic.php?f=7&t=16297
	  LDA KEYVH
            CMP #&FF
            BNE notExtendedVectorGROM
            LDA #&0D
            STA osRdRmPtr
            LDA #&80
            STA osRdRmPtr + 1
            LDY XKEYVBank
            JSR OSRDRM
            CMP #'G'
            BNE notExtendedVectorGROM
            LDA XKEYVBank
            ORA #romselMemsel
            STA XKEYVBank
.notExtendedVectorGROM
            CLC
            JSR SFTODOALARMSOMETHING
            BIT L03A4
            BPL L9611
            JMP L964C
			
.L9611      JSR PrvEn								;switch in private RAM
            LDX lastBreakType								;get last Break type
            CPX #&01								;power on break?
            BNE notPowerOnStarBoot							;branch if not
            CLC
            LDA prvBootSFTODO								;get data from Private RAM
            BEQ notPowerOnStarBoot							;branch if we don't have a *BOOT command in effect
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
.notPowerOnStarBoot
            JSR PrvDis								;switch out private RAM
            LDA #osbyteKeyboardScanFrom10
            JSR OSBYTE
            CPX #keycodeNone
            BEQ noKeyPressed
.L964C      LDX romselCopy
            DEX
            JMP selectFirstFilingSystemROMLessEqualXAndLanguage
			
.noKeyPressed
	  LDA lastBreakType
            BNE notSoftReset1
            LDX #&43
            JSR readPrivateRam8300X							;read data from Private RAM &83xx (Addr = X, Data = A)
            PHA ; SFTODO: Why can't we just do the read from &8343 *after* JSR setDfsNfsPriority and avoid this PHA/PLA?
            JSR setDfsNfsPriority
            PLA
            AND #&7F
            TAX
            CPX romselCopy
            BCC selectFirstFilingSystemROMLessEqualXAndLanguage
.notSoftReset1
            JSR setDfsNfsPriority
            JMP selectConfiguredFilingSystemAndLanguage

.setDfsNfsPriority
            LDX #userRegDiscNetBootData							;Register &10 (0: File system disc/net flag / 4: Boot / 5-7: Data )
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            ROR A
            ROR A									;Move File system bit to msb
            AND #&80								;and isolate bit
            TAX
            LDA #osbyteReadWriteStartupOptions						;select read / write start-up options
            LDY #&7F								;retain lower 7 bits
            JSR OSBYTE								;execute read / write start-up options
            RTS

.selectConfiguredFilingSystemAndLanguage
            LDX #userRegLangFile
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            AND #&0F								;get *CONFIGURE FILE value
            TAX
	  ; SFTODO: If the selected filing system is >= our bank, start one bank lower?! This seems odd, although *if* we know we're bank 15, this really just means "start below us" (presumably to avoid infinite recursion)
            CPX romselCopy
            BCC selectFirstFilingSystemROMLessEqualXAndLanguage
            DEX
.selectFirstFilingSystemROMLessEqualXAndLanguage
            JSR passServiceCallToROMsLessEqualX
            LDA lastBreakType
            BNE notSoftReset
            LDA currentLanguageRom
            BPL enterLangA ; SFTODO: Do we expect this to always branch? Not at all sure.
.notSoftReset
	  LDX #userRegLangFile
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            JSR lsrA4								;get *CONFIGURE LANG value
            JMP enterLangA
			
.noTube     LDA romselCopy
.enterLangA TAX
            LDA romTypeTable,X
            ROL A
            BPL noLanguageEntry
            JMP LDBE6								;OSBYTE 142 - ENTER LANGUAGE ROM AT &8000 (http://mdfs.net/Docs/Comp/BBC/OS1-20/D940) - we enter one byte early so carry is clear, which might indicate "initialisation" (this based on that mdfs.net page; I can't find anything about this in a quick look at other documentation)

.noLanguageEntry
            BIT tubePresenceFlag								;check for Tube - &00: not present, &ff: present
            BPL noTube
            LDA #&00
            CLC
            JMP L0400								;assume there is code within this ROM that is being relocated to &0400???

; SFTODO: This has only one caller
.passServiceCallToROMsLessEqualX
.L96BC      TXA
            PHA
            TSX
            LDA L0104,X								;get Y from the service call
            TAY ; SFTODO: Just use LDY L0104,X to load directly?
            PLA
            TAX
            LDA romselCopy
            PHA
            LDA #&03								;service call number
            JMP LF16E								;OSBYTE 143 - Pass service commands to sideways ROMs (http://mdfs.net/Docs/Comp/BBC/OS1-20/F135), except we enter partway through to start at bank X not bank 15
}

;Absolute workspace claim - Service call &01
; SFTODO: I think this code is high enough in the IBOS ROM we don't need to be indirecting via writePrivateRam8300X and could just set PRV1 and access directly?
.service01
{
tmp = &A8
            LDA #&00
            STA ramselCopy
            STA ramsel								;shadow off
            LDX #&07								;start at address 7
            LDA #&FF								;set data to &FF
.writeLoop  JSR writePrivateRam8300X							;write data to Private RAM &83xx (Addr = X, Data = A)
            DEX									;repeat
            BNE writeLoop								;until 0. (but not writing to &8300)
            LDA romselCopy								;get current ROM number
            AND #maxBank								;mask
	  ASSERT prvIbosBankNumber == prv83 + 0
            JSR writePrivateRam8300X							;write data to Private RAM &83xx (Addr = X, Data = A)
            BIT L03A4								;?
            BPL L96EE
            JMP ExitServiceCallIndirect
			
.L96EE      LDX #userRegPrvPrintBufferStart
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            LDX #prvPrvPrintBufferStart-prv83                                                       ; SFTODO: not too happy with this format
            JSR writePrivateRam8300X							;write data to Private RAM &83xx (Addr = X, Data = A)
            LDX lastBreakType
            BEQ softReset
            LDX #userRegOsModeShx							;0-2: OSMODE / 3: SHX
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            PHA
            AND #&07								;mask OSMODE value
            LDX #prvOsMode - prv83							;select OSMODE register
            JSR writePrivateRam8300X							;write data to Private RAM &83xx (Addr = X, Data = A)
            JSR assignDefaultPseudoRamBanks						;Assign default pseudo RAM banks to absolute RAM banks
            PLA
            AND #&08								;mask off SHX bit
            BEQ shxInA
            LDA #&FF
.shxInA     LDX #prvShx - prv83							;select SHX register (&08: On, &FF: Off)
            JSR writePrivateRam8300X							;write data to Private RAM &83xx (Addr = X, Data = A)
.softReset
.L9719      JSR IbosSetUp
            LDX #userRegModeShadowTV							;get TV / MODE parameters
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
	  ; Arithmetic shift A right 5 bits to get a sign-extended version of the TV setting in A.
	  ; SFTODO: Could we optimise this using technique from http://wiki.nesdev.com/w/index.php/6502_assembly_optimisations#Arithmetic_shift_right?
            PHA									;save value
            ROL A									;move msb to carry
            PHP									;save msb
            ROR A									;move bit from carry back to msb
            LDX #&05								;set counter to 5: move bits 8-5 to 3-0. Pad upper bits with msb
.shiftLoop  PLP									;recover msb
            PHP									;and save again
            ROR A									;store bit to msb
            DEX
            BNE shiftLoop								;loop for 5
            PLP
            TAX									;then save TV setting in X
            PLA									;recover parameter &0A value
            AND #&10								;is bit 4 set (TV interlace)?
            BEQ interlaceInA								;no? then jump to set Y=0
            LDA #&01								;else set Y=1
.interlaceInA
	  TAY									;set Y=0
            LDA #osbyteTV								;select *TV X,Y
            JSR OSBYTE								;execute *TV X,Y
	  ; Set the screen mode. On a soft reset we preserve the last selected
	  ; mode (like the Master), unless we're in OSMODE 0; on other resets
	  ; we select the *CONFIGUREd mode.
            LDA #vduSetMode								;select switch MODE
            JSR OSWRCH								;write switch MODE
            LDX lastBreakType								;Read Hard / Soft Break
            BNE dontPreserveScreenMode							;Branch on hard break (power on / Ctrl Break)
            LDX #prvOsMode - prv83							;select OSMODE
            JSR readPrivateRam8300X							;read data from Private RAM &83xx (Addr = X, Data = A)
            BEQ dontPreserveScreenMode							;branch if OSMODE=0
            LDX #prvSFTODOMODE - prv83							;read mode? SFTODO: OK, so probably prvSFTODOMODE is the (configured?) screen mode? That would account for b7 being shadow-ish
            JSR readPrivateRam8300X							;read data from Private RAM &83xx (Addr = X, Data = A)
            JSR OSWRCH								;write mode?
            JMP screenModeSet

.dontPreserveScreenMode
            LDX #userRegModeShadowTV							;get MODE value - Shadow: bit 3, Mode: bits 0, 1 & 2
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            AND #&0F								;Lower nibble only
	  ; Map the "compressed mode" in the range 0-15 to 0-7 or 128-135.
            CMP #maxMode + 1
            BCC screenModeInA
            ADC #(shadowModeOffset - (maxMode + 1)) - 1					;-1 because C is set
.screenModeInA
	  JSR OSWRCH								;Write MODE
.screenModeSet
	  JSR displayBannerIfRequired
            LDX #userRegKeyboardDelay							;get keyboard auto-repeat delay (cSecs)
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            TAX
            LDA #osbyteSetAutoRepeatDelay						;select keyboard auto-repeat delay
            JSR OSBYTE								;write keyboard auto-repeat delay
            LDX #userRegKeyboardRepeat							;get keyboard auto-repeat rate (cSecs)
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            TAX
            LDA #osbyteSetAutoRepeatPeriod						;select keyboard auto-repeat rate
            JSR OSBYTE								;write keyboard auto-repeat rate
            LDX #userRegPrinterIgnore							;get character ignored by printer
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            TAX
            LDA #osbyteSetPrinterIgnore							;select character ignored by printer
            JSR OSBYTE								;write character ignored by printer
            LDX #userRegTubeBaudPrinter							;get RS485 baud rate for receiving and transmitting data (bits 2,3,4) & printer destination (bit 5)
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            JSR lsrA2								;2 x LSR
            PHA
            AND #&07								;get lower 3 bits
            CLC
            ADC #&01								;increment to convert to baud rate
            PHA
            TAX									;baud rate value
            LDA #osbyteSetSerialReceiveRate						;select RS485 baud rate for receiving data
            JSR OSBYTE								;write RS485 baud rate for receiving data
            PLA
            TAX									;baud rate value
            LDA #osbyteSetSerialTransmitRate						;select RS485 baud rate for transmitting data
            JSR OSBYTE								;write RS485 baud rate for transmitting data
            PLA
            JSR lsrA3								;3 x LSR
            TAX
            LDA #osbyteSetPrinterType							;select printer destination
            JSR OSBYTE								;write printer destination
            LDX #userRegFdriveCaps
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            PHA
            AND #%00111000								;get CAPS bits
            LDX #&A0								;CAPS Lock Engaged + Shift Enabled?
            CMP #&08								;CAPS Lock Engaged?
            BEQ capsInA
            LDX #&30								;
            CMP #&10								;SHIFT Lock Engaged?
            BEQ capsInA
            LDX #&20
.capsInA    LDY #&00
            LDA #osbyteReadWriteKeyboardStatus						;select keyboard status byte
            JSR OSBYTE								;write keyboard status byte
            PLA
	  ; SFTODO: This is a little odd - we're masking off the 3 bits allocated to FDRIVE, but the *FX255 command only allows
	  ; two bits for FDRIVE - our top FDRIVE bit will be put in b6 of the *FX255 argument. I suppose this does allow control
	  ; over the filing-system specific interpretation for b6. No we won't, because we force b6-7 clear below anyway. So
	  ; this is harmless but still a little odd.
            AND #%00000111								;get FDRIVE bits
            ASL A
            ASL A
            ASL A
            ASL A
            STA tmp
            LDX #userRegDiscNetBootData							;Register &10 (0: File system / 4: Boot / 5-7: Data )
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            PHA
            LDY #%11001000								;preserve b7, b6 and b3 (boot flag) on soft reset
            LDA lastBreakType
            BEQ bootInAMaskInY							;branch if soft reset
	  ; Get the boot flag from userRegDiscNetBootData into b3 of A
            PLA
            PHA
	  ; SFTODO: So where do we set b7 to select NFS or DFS priority? I wonder if this has been bodged in slightly and could be more efficiently handled here, but perhaps there's a good reason for doing it elsewhere.
            LDY #%11000000								;preserve b6-7 of startup options on non-soft reset SFTODO: presumably from keyboard links? would it be a worthwhile enhancement to allow IBOS to control *all* bits of the startup options?
            LSR A
            AND #1<<3
            EOR #1<<3
.bootInAMaskInY
            ORA tmp
            ORA #%00000111								;force mode 7 SFTODO: seems a bit pointless but harmless, I guess
            AND #%00111111
            TAX
            LDA #osbyteReadWriteStartupOptions
            JSR OSBYTE
	  ; Set the baud rate directly on the ACIA. SFTODO: Is that right? Why do we need this, since we're setting it via the OS using OSBYTE above anyway?
            PLA									;get userRegDiscNetBootData value
            JSR lsrA3
            AND #%00011100								;A="data" (baud rate) shifted into b2-4
            TAX
            LDY #&E3
            LDA #osbyteReadWriteAciaRegister
            JSR OSBYTE
.ExitServiceCallIndirect
            JMP ExitServiceCall								;restore service call parameters and exit
}

; SFTODO: lsrA4 has only one caller (but there are places where it should be used and isn't)
.lsrA4      LSR A
; SFTODO: Use of JSR lsrA3 or JSR lsrA2 is silly - the former is neutral on space and slower, the latter is both larger and slower
.lsrA3      LSR A
.lsrA2      LSR A
            LSR A
            RTS

;Tube system initialisation - Service call &FF
{
.^serviceFF JSR clearShenPrvEn
            PHA
            BIT prvSFTODOTUBEISH
            BMI L9836
            LDA lastBreakType
            BEQ softReset
            BIT L03A4
            BMI L983D
            LDX #userRegTubeBaudPrinter
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            AND #&01 ; mask off tube bit (SFTODO: named constant? or more trouble than it's worth?)
            BNE L982E
            LDA #&FF
.L982E      STA prvSFTODOTUBE2ISH
.softReset  BIT prvSFTODOTUBE2ISH
	  BPL L983D
.L9836      PLA
            JSR PrvDisStaRamsel
            JMP ExitServiceCall								;restore service call parameters and exit
			
.L983D      PLA
            JSR PrvDisStaRamsel
            PLA
            TAY
            PLA
            PLA
            LDA #&FF
            LDX #&00
            JMP LDC16								;Set up Sideways ROM latch and RAM copy (http://mdfs.net/Docs/Comp/BBC/OS1-20/D940)

; SFTODO: This only has one caller
.clearShenPrvEn ; SFTODO: not super happy with this name
.L984C      LDA ramselCopy
            PHA
            LDA #&00
            STA ramselCopy
            STA ramsel
            JSR PrvEn								;switch in private RAM
            PLA
            RTS

.PrvDisStaRamsel
.L985D      PHA
            JSR PrvDis								;switch out private RAM
            PLA
            STA ramselCopy
            STA ramsel
            RTS
}

;Vectors claimed - Service call &0F
{
.^service0F  LDX #&43
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
            JMP ExitServiceCall								;restore service call parameters and exit
}

; SFTODO: This has only one caller
; SFTODO: At least in b-em, I note that with a second processor, we get the INTEGRA-B banner *as well as* the tube banner. This doesn't happen with the standard OS banner. Arguably this is desirable, but we *could* potentially not show our own banner if we have a second processor attached to be more "standard".
; SFTODO: Perhaps a bit of a novelty, but could we make the startup banner *CONFIGURE-able?
.displayBannerIfRequired
{
ramPresenceFlags = &A8
.L989F      LDX #prvOsMode - prv83							;select OSMODE
            JSR readPrivateRam8300X							;read data from Private RAM &83xx (Addr = X, Data = A)
            CMP #&00								;If OSMODE=0 SFTODO: Could save a byte with "TAX"
            BEQ rts									;Then leave startup message alone
            LDA #osbyteEnableDisableStartupMessage					;Startup message suppression and !BOOT option status
            LDX #&00
            LDY #&FF
            JSR OSBYTE
            TXA
            BPL rts
            LDA #osbyteEnableDisableStartupMessage					;Startup message suppression and !BOOT option status
            LDX #&00
            LDY #&00
            JSR OSBYTE
            LDX #computechStart - romHeader						;Start at ROM header offset &17
.bannerLoop1
	  LDA romHeader,X								;Read 'Computech ' from ROM header
            JSR OSWRCH								;Write to screen
            INX									;Next Character
            CPX #(computechEnd + 1) - romHeader						;Check for final character
            BNE bannerLoop1								;Loop
            LDX #(reverseBannerEnd - 1) - reverseBanner					;Lookup table offset
.bannerLoop2
	  LDA reverseBanner,X							;Read INTEGRA-B Text from lookup table
            JSR OSWRCH								;Write to screen
            DEX									;Next Character
            BPL bannerLoop2								;Loop
            LDA lastBreakType								;Check Break status. 0=soft, 1=power up, 2=hard
            BEQ softReset								;No Beep and don't write amount of Memory to screen
            LDA #vduBell								;Beep
            JSR OSWRCH								;Write to screen
            LDX #userRegRamPresenceFlags						;Read 'RAM installed in banks' register
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            STA ramPresenceFlags
            LDX #&07								;Check all 8 32k banks for RAM
            LDA #&00								;Start with 0k RAM
.countLoop  LSR ramPresenceFlags							;Check if RAM bank
            BCC notPresent								;If 0 then no RAM, so don't increment RAM count
            ADC #32 - 1								;Add 32k (-1 because carry is set)
.notPresent DEX									;Check next 32k bank
            BPL countLoop								;Loop until 0
            CMP #&00								;If RAM total = 0k (will occur with either 0 RAM banks or 8 x 32k RAM banks), then SFTODO: could do "TAX" to save a byte
            BEQ allBanksPresent							;Write '256K' to screen
	  ; SFTODO: We could save the SEC by just doing JSR printADecimalPad
	  ; SFTODO: Do we really want padding here? If we have (say) 64K, surely it's neater to print "Computech INTEGRA-B 64K" not "Computech INTEGRA-B  64K"?
            SEC
            JSR printADecimal								;Convert binary number to numeric characters and write characters to screen
            JMP printKAndNewline							;Write 'K' to screen

.allBanksPresent
            LDA #'2'
            JSR OSWRCH								;Write to screen
            LDA #'5'
            JSR OSWRCH								;Write to screen
            LDA #'6'
            JSR OSWRCH								;Write to screen
.printKAndNewline
            LDA #'K'
            JSR OSWRCH								;Write to screen
.softReset  JSR OSNEWL								;New Line
            BIT tubePresenceFlag							;check for Tube - &00: not present, &ff: present
            BMI rts
            JMP OSNEWL								;New Line

	  ; SFTODO: Control can't flow through to here, can we move the rts label to a nearby rts to save a byte?
.rts        RTS

.reverseBanner
       	  EQUS " B-ARGETNI"							;INTEGRA-B Reversed
.reverseBannerEnd
}

; SFTODO: There are a few cases where we JMP to osbyteXXInternal, if we rearranged the code a little (could always use macros to maintain readability, if that's a factor) we could probably save some JMPs
.osbyte44Internal
{
.L9928	  JSR PrvEn								;switch in private RAM
            PHP
            SEI
            LDA #&00
            STA oswdbtX
            LDY #&03
.L9933      STY prvTmp
            LDA prvPseudoBankNumbers,Y
            BMI L994A
            TAX
            JSR testRamUsingVariableMainRamSubroutine
            BNE L994A
            LDA prvRomTypeTableCopy,X
            BEQ L994D
            CMP #&02
            BEQ L994D
.L994A      CLC
            BCC L994E
.L994D      SEC
.L994E      ROL oswdbtX
            LDY prvTmp
            DEY
            STY prvTmp
            BPL L9933
            JMP plpPrvDisexitSc
}

;OSBYTE &45 (69) - Test PSEUDO/Absolute usage (http://beebwiki.mdfs.net/OSBYTE_%2645)
.osbyte45Internal
{
.L995C      JSR PrvEn								;switch in private RAM
            PHP
            SEI
            LDA #&00
            STA oswdbtX
	  ; SFTODO: Is all the saving and restoring of Y needed? findAInPrvSFTODOFOURBANKS doesn't seem to corrupt Y.
            LDY #&03
.bankLoop   STY prvTmp
            LDA prvPseudoBankNumbers,Y
            BMI bankAbs   								;&FF indicates no absolute bank assigned to this pseudo-bank SFTODO: I guess we say that's an absolute addressing bank as it is less likely our caller will decide to try to use it, but it is a bit arbitrary
            JSR findAInPrvSFTODOFOURBANKS ; SFTODO: I am inferring SFTODOFOURBANKS is therefore a list of up to 4 banks being used for pseudo-addressing - the fact we need to do the previous BMI suggests the list is padded to the full 4 entries with &FF
            BPL bankPseudo								;branch if we found a match
.bankAbs    CLC
            BCC bankStateInC
.bankPseudo SEC
.bankStateInC
            ROL oswdbtX
            LDY prvTmp
            DEY
            STY prvTmp
            BPL bankLoop
.^plpPrvDisexitSc
.L9983      PLP
            JMP PrvDisexitSc
}
			
;*SRWIPE Command
.srwipe
{
	  JSR parseRomBankListChecked2
            JSR PrvEn								;switch in private RAM
            LDX #&00
.bankLoop   ROR transientRomBankMask + 1
            ROR transientRomBankMask
            BCC skipBank
            JSR wipeBankAIfRam
.skipBank   INX
            CPX #maxBank + 1
            BNE bankLoop
            JMP PrvDisexitSc

; SFTODO: This has only one caller, the code immediately above - could it just be inlined?
.wipeBankAIfRam
            JSR testRamUsingVariableMainRamSubroutine
            BNE rts
            PHA
            LDX #lo(wipeRamTemplate)							;LSB of relocatable Wipe RAM code
            LDY #hi(wipeRamTemplate)							;MSB of relocatable Wipe RAM code
            JSR copyYxToVariableMainRamSubroutine						;relocate &32 bytes of Wipe RAM code from &9E38 to &03A7
            PLA
            JSR variableMainRamSubroutine						;Call relocated Wipe RAM code
            PHA
            JSR removeBankAFromSFTODOFOURBANKS						;SFTODO: So *SRWIPE implicitly performs a *SRROM on each bank it wipes?
            PLA
            TAX
            LDA #&00
            STA romTypeTable,X							;clear ROM Type byte
            STA prvRomTypeTableCopy,X							;clear Private RAM copy of ROM Type byte
.rts        RTS
}

; SFTODO: Dead data
{
	  EQUS "RAM","ROM"
}

; SFTODO: This has only one caller
; A=0 on entry means the header should say "RAM", otherwise it will say "ROM". A is also copied into the (unused) second byte of the bank's service entry; SFTODO: I don't know why specifically, but maybe this is just done because that's what the Acorn DFS SRAM utilities do (speculation; I haven't checked).
.writeRomHeaderAndPatchUsingVariableMainRamSubroutine
{
.L99C6	  PHA
	  LDX #lo(writeRomHeaderTemplate)
	  LDY #hi(writeRomHeaderTemplate)
	  JSR copyYxToVariableMainRamSubroutine						;relocate &32 bytes of code from &9E59 to &03A7
            PLA
            BEQ ram
            ; ROM - so patch variableMainRamSubroutine's ROM header to say "ROM" instead of "RAM"
            LDA #'O'
            STA variableMainRamSubroutine + (writeRomHeaderTemplateDataAO - writeRomHeaderTemplate)
.ram        LDA prvOswordBlockCopy + 1 ; SFTODO: THIS IS THE SAME LOCATINO AS IN SRROM/SRDATA SO WE NEED A GLOBAL NAME FOR IT RATHER THAN JUST THE LOCAL ONE WE CURRENTLY HAVE (bankTmp)
            JSR checkRamBankAndMakeAbsolute
            STA prvOswordBlockCopy + 1
            STA variableMainRamSubroutine + (writeRomHeaderTemplateSFTODO - writeRomHeaderTemplate)
            JMP variableMainRamSubroutine						;Call relocated code
}

{
; Search prvSFTODOFOURBANKS for A; if found, remove it, shuffling the elements down so all the non-&FF entries are at the start and are followed by enough &FF entries to fill the list.
.^removeBankAFromSFTODOFOURBANKS
.L99E5      LDX #&03
.findLoop   CMP prvSFTODOFOURBANKS,X
            BEQ found
            DEX
            BPL findLoop
            SEC ; SFTODO: Not sure any callers care about this, and I think we'll *always* exit with carry set even if we do find a match
            RTS

.found      LDA #&FF
            STA prvSFTODOFOURBANKS,X
.shuffle    LDX #&00
            LDY #&00
.shuffleLoop
	  LDA prvSFTODOFOURBANKS,X
            BMI unassigned
            STA prvSFTODOFOURBANKS,Y
            INY
.unassigned INX
            CPX #&04
            BNE shuffleLoop
            TYA
            TAX
            JMP padLoopStart
			
.padLoop    LDA #&FF
            STA prvSFTODOFOURBANKS,Y
            INY
.padLoopStart
	  CPY #&04
            BNE padLoop
            RTS

; If there's an unused entry, add A to SFTODOFOURBANKS and return with C clear, otherwise return with C set to indicate no room.
; SFTODO: This has only one caller
.^addBankAToSFTODOFOURBANKS
.L9A18      PHA
            JSR shuffle
            PLA
            CPX #&04
            BCS rts
            STA prvSFTODOFOURBANKS,X
.rts        RTS
}

; Return with X such that prvSFTODOFOURBANKS[X] == A (N flag clear), or with X=-1 if there is no such X (N flag set).
; SFTODO: This only has one caller
.findAInPrvSFTODOFOURBANKS
{
.L9A25      LDX #&03
.loop       CMP prvSFTODOFOURBANKS,X
            BEQ rts
            DEX
            BPL loop
.rts        RTS
}

;*SRSET Command
{
.^srset     LDA (transientCmdPtr),Y
            CMP #'?'
            BEQ showStatus
	  ; Select the first four suitable banks from the list provided and store them at prvPseudoBankNumbers.
            JSR parseRomBankList
            JSR PrvEn								;switch in private RAM
            LDX #&00
            LDY #&00
.bankLoop   ROR transientRomBankMask + 1
            ROR transientRomBankMask
            BCC skipBank
            TYA
            PHA
            JSR testRamUsingVariableMainRamSubroutine
            BNE plyAndSkipBank 							;branch if not RAM
            LDA prvRomTypeTableCopy,X
            BEQ emptyBank
            CMP #romTypeSrData
            BNE plyAndSkipBank
.emptyBank  CLC
            BCC skipIffC
.plyAndSkipBank
	  SEC
.skipIffC   PLA
            TAY
            BCS skipBank
            TXA
            STA prvPseudoBankNumbers,Y
            INY
            CPY #&04
            BCS done
.skipBank   INX
            CPX #maxBank + 1
            BNE bankLoop
	  ; There aren't four entries in prvPseudoBankNumbers (if there were we'd have taken the "BCS done" branch above), so pad the list with &FF entries.
            LDA #&FF
.padLoop    STA prvPseudoBankNumbers,Y
            INY
            CPY #&04
            BCC padLoop
.done       JMP PrvDisexitSc

.showStatus
            CLC
            JSR PrvEn								;switch in private RAM
            LDY #&00
.showLoop   CLC
            TYA
            ADC #'W'								;Start at 'W'
            JSR OSWRCH
            LDA #'='
            JSR OSWRCH								;Write to screen
            LDA prvPseudoBankNumbers,Y							;read absolute bank assigned to psuedo bank
            BPL showAssignedBank							;check if valid bank has been assigned
            LDA #'?'
            JSR OSWRCH								;Write to screen
            JMP bankShown
.showAssignedBank
            SEC
            JSR printADecimal								;Convert binary number to numeric characters and write characters to screen
.bankShown  CPY #&03								;Check for 4th bank
            BEQ osnewlPrvDisexitSc							;Yes? Then end
            LDA #','
            JSR OSWRCH								;Write to screen
            JSR printSpace								;write ' ' to screen
            INY									;Next
            BNE showLoop								;Loop for 'X', 'Y' & 'Z'
.osnewlPrvDisexitSc
            JSR OSNEWL								;New Line
            JMP PrvDisexitSc
}

{
;*SRROM Command
.^srrom	  SEC
            BCS common

;*SRDATA Command
.^srdata
            CLC
.common     PHP
            JSR parseRomBankListChecked2
            JSR PrvEn								;switch in private RAM
            LDX #&00
.bankLoop   ROR transientRomBankMask + 1
            ROR transientRomBankMask
            BCC skipBank
            PLP
            PHP
            JSR doBankX
.skipBank   INX
            CPX #maxBank + 1
            BNE bankLoop
            JMP plpPrvDisexitSc

; SFTODO: This has only one caller, just above, can it simply be inlined?
; SFTODO: This seems to remove and maybe re-add (depending on C on entry; C set means SRROM, C clear means SRDATA) bank X to SFTODOFOURBANKS, but only adding if X is suitable.
; SFTODO: This seems to use L00AD as scratch space too - is there really no second zero page (=> shorter code) location we could have used instead of prvOswordBlockCopy + 1?
; SFTODO: Probably not, but is there any chance of sharing more code between this and srset?
; SFTODO: I think this returns with C clear on success, C set on error - if C is set, V indicates something - *but* our one caller doesn't seem to check C or V, so this is a bit pointless
bankTmp = prvOswordBlockCopy + 1 ; we just use this as scratch space SFTODO: ah, maybe we are just using this location because other really-OSWORD code uses the same subroutines which expect the bank to be in this location
romRamFlagTmp = L00AD ; &80 for *SRROM, &00 for *SRDATA SFTODO: Use a "proper" label on RHS
.doBankX
            STX bankTmp
            PHP
            LDA #&00
            ROR A
            STA romRamFlagTmp
            JSR testRamUsingVariableMainRamSubroutine
            BNE failSFTODOA								;branch if not RAM
            LDA prvRomTypeTableCopy,X
            BEQ emptyBank
            CMP #romTypeSrData
            BNE failSFTODOA
.emptyBank  LDA bankTmp
            JSR removeBankAFromSFTODOFOURBANKS
            PLP
            BCS isSrrom
            LDA bankTmp
            JSR addBankAToSFTODOFOURBANKS
            BCS failSFTODOB ; SFTODO: branch if we already had four banks and so couldn't add this one
.isSrrom    LDA romRamFlagTmp
            JSR writeRomHeaderAndPatchUsingVariableMainRamSubroutine
            LDX bankTmp
            LDA #romTypeSrData
            STA prvRomTypeTableCopy,X
            STA romTypeTable,X
.restoreXRts
	  LDX bankTmp
.rts        RTS

.failSFTODOA
	  PLP
            SEC
            CLV
            BCS restoreXRts ; always branch
.failSFTODOB
	  SEC
            BIT rts ; set V
            BCS restoreXRts ; always branch
}

{
.^checkRamBankAndMakeAbsolute
.L9B18      AND #&7F								;drop the highest bit
            CMP #maxBank + 1								;check if RAM bank is absolute or pseudo address
            BCC rts
            TAX
            ; SFTODO: Any danger this is ever going to have X>3 and access an arbitrary byte?
            LDA prvPseudoBankNumbers,X							;lookup table to convert pseudo RAM W, X, Y, Z into absolute address???
            BMI badIdIndirect								;check for Bad ID
.rts        RTS
}


; SFTODO: Do we really need this *and* parseRomBankListChecked? Isn't parseRomBankListChecked better than this one?
.parseRomBankListChecked2
{
.L9B25      JSR parseRomBankList
            BCS badIdIndirect
            RTS
}

.badIdIndirect
.L9B2B      JMP badId						;Error Bad ID


; SFTODO: This has only one caller
; Given a sideways RAM pseudo-address in AY, convert it to a relative bank number 0-3 in X and an absolute sideways RAM address in AY.
.convertPseudoAddressToAbsolute
{
pseudoAddressingBankHeaderSize = &10
pseudoAddressingBankDataSize = &4000 - pseudoAddressingBankHeaderSize
.L9B2E      LDX #&00
.loop       STY transientOs4243SFTODO
            STA transientOs4243SFTODO + 1
            SEC
            LDA transientOs4243SFTODO
            SBC #lo(pseudoAddressingBankDataSize)
            TAY
            LDA transientOs4243SFTODO + 1
            SBC #hi(pseudoAddressingBankDataSize)
            BCC noBorrow
            INX
            BNE loop
.noBorrow   CLC
            LDA transientOs4243SFTODO
            ADC #lo(pseudoAddressingBankHeaderSize)
            TAY
            LDA transientOs4243SFTODO + 1
            ADC #hi(pseudoAddressingBankHeaderSize)
            ORA #&80
            RTS
}

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
	  ; SFTODO: What do these addresses hold? I *speculate* they hold the real banks assigned to pseudo-banks W-Z, &FF meaning "not assigned".
            LDA prvSFTODOFOURBANKS
            AND prvSFTODOFOURBANKS + 1
            AND prvSFTODOFOURBANKS + 2
            AND prvSFTODOFOURBANKS + 3
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
            BEQ GenerateSyntaxErrorIndirect
            INY
            BNE L9C30
.L9C3D      INY
            RTS
}
			
.GenerateSyntaxErrorIndirect
	  JMP GenerateSyntaxError

.L9C42      JSR convertIntegerDefaultHex
            BCS GenerateSyntaxErrorIndirect
            LDA L00B0
            STA prvOswordBlockCopy + 8
            LDA L00B1
            STA prvOswordBlockCopy + 9
            RTS

{
.^L9C52      JSR findNextCharAfterSpace								;find next character. offset stored in Y
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
.L9C71      STA prvOswordBlockCopy + 3
            LDA #&00
            STA prvOswordBlockCopy + 2
            STA prvOswordBlockCopy + 4
            STA prvOswordBlockCopy + 5
            PLA
            TAY
            RTS
}
			
; Parse a 32-bit hex-default value from the command line and store it in the "buffer address" part of prvOswordBlockCopy. (Some callers will move it from there to where they really want it afterwards.)
.parseOsword4243BufferAddress
{
.L9C82      JSR convertIntegerDefaultHex
            BCS GenerateSyntaxErrorIndirect
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
            BCS GenerateSyntaxErrorIndirect
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

.L9CC7      LDA L00B0
            STA prvOswordBlockCopy + 6
            LDA L00B1
            STA prvOswordBlockCopy + 7
            RTS
}

{
;*SRREAD Command
.^srread	  JSR PrvEn								;switch in private RAM
            LDA #&00
            JMP L9CDF
			
;*SRWRITE Command
.^srwrite	  JSR PrvEn								;switch in private RAM
            LDA #&80
.L9CDF      STA prvOswordBlockCopy
            LDA #&00
            STA L02EE
            JSR L9C52
            JSR parseOsword4243Length
            JSR L9C42
            JSR parseBankNumberIfPresent
            JMP LA0A6
}

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
.L9D62      BIT prvOswordBlockCopy                                                                  ;get function
            BVC secSevRts                                                                           ;branch if we have an absolute address
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
            BCS secSevRts
            TAX
            LDA prvSFTODOFOURBANKS,X
            BMI clvSecRts
            TAX
.clcRts
.L9D84      CLC
            RTS

.secSevRts
.badDate3
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
            LDA prvSFTODOFOURBANKS,X
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
            JSR CloseHandleL02EE
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
            JSR convertPseudoAddressToAbsolute
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
.L9E62      LDA variableMainRamSubroutine + srDataHeader - writeRomHeaderTemplate,Y
            STA &8000,Y    
            DEY
            BPL L9E62
            LDA romselCopy
            STX romselCopy
            STX romsel
            RTS

;ROM Header
.srDataHeader
	  EQUB &60
.^writeRomHeaderTemplateSFTODO ; SFTODO: Why do we modify this byte of the header?
            EQUB     &00,&00
	  EQUB &60,&00,&00
	  EQUB romTypeSrData ; SFTODO: This constant is arguably misnamed since we use it for *SRROM banks too (I think)
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
ptr = &AC ; 2 bytes
.L9F33      LDA ptr + 1
            PHA
            LDA ptr
            PHA
            STX ptr
            STY ptr + 1
            LDY #variableMainRamSubroutineMaxSize - 1
.L9F3F      LDA (ptr),Y
            STA variableMainRamSubroutine,Y
            DEY
            BPL L9F3F
            PLA
            STA ptr
            PLA
            STA ptr + 1
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

.CloseHandleL02EE
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
.LA0BC      JMP plpPrvDisexitSc
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
.LA22B      JSR CloseHandleL02EE
.LA22E      BIT prvOswordBlockCopy                                                                  ;function
            BPL PrvDisexitScIndirect                                                                ;branch if read
            BVS PrvDisexitScIndirect                                                                ;branch if pseudo-address
            LSR prvOswordBlockCopy                                                                  ;function
            ; SFTODO: Why are we testing the low bit of 'function' here? The defined values always have this 0. Is something setting this internally to flag something?
            BCC LA240 ; SFTODO: always branch? At least during an official user-called OSWORD &43 we will, as low bit should always be 0 according to e.g. Master Ref Manual
            LDA prvOswordBlockCopy + 1                                                              ;absolute ROM number
            JSR createRomBankMaskAndInsertBanks
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
            JMP ExitAndClaimServiceCall								;Exit Service Call
}

.parseRomBankListChecked
{
.LA2E4      JSR parseRomBankList
            BCC rts
            BVC GenerateSyntaxErrorIndirect
.^badId
.LA2EB      JSR raiseError								;Goto error handling, where calling address is pulled from stack

	  EQUB &80
	  EQUS "Bad id", &00

.GenerateSyntaxErrorIndirect
            JMP GenerateSyntaxError

	  ; SFTODO: Can we repurpose another nearby RTS and get rid of this?
.rts        RTS
}

;*INSERT Command
{
.^insert    JSR parseRomBankListChecked								;Error check input data
            LDX #userRegBankInsertStatus						;get *INSERT status
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            ORA transientRomBankMask								;update *INSERT status
            JSR writeUserReg								;Write to RTC clock User area. X=Addr, A=Data
            LDX #userRegBankInsertStatus + 1
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            ORA transientRomBankMask + 1
            JSR writeUserRegAndCheckNextCharI						;Check for Immediate 'I' flag
            BNE exitSCIndirect1								;Exit if not immediate
            INY
            JSR insertBanksUsingTransientRomBankMask					;Initialise inserted ROMs
.exitSCIndirect1
            JMP ExitAndClaimServiceCall								;Exit Service Call

.writeUserRegAndCheckNextCharI
            JSR writeUserReg								;Write to RTC clock User area. X=Addr, A=Data
            JSR findNextCharAfterSpace							;find next character. offset stored in Y
            LDA (transientCmdPtr),Y
            AND #&DF								;Capitalise
            CMP #'I'								;and check for 'I' (Immediate)
            RTS

;*UNPLUG Command
.^unplug	  JSR parseRomBankListChecked								;Error check input data
            JSR invertTransientRomBankMask								;Invert all bits in &AE and &AF
            LDX #&06								;INSERT status for ROMS &0F to &08
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            AND L00AE
            JSR writeUserReg								;Write to RTC clock User area. X=Addr, A=Data
            LDX #&07								;INSERT status for ROMS &07 to &00
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            AND L00AF
            JSR writeUserRegAndCheckNextCharI						;Check for Immediate 'I' flag
            BNE exitSCIndirect2
            INY
            JSR unplugBanksUsingTransientRomBankMask
.exitSCIndirect2
            JMP ExitAndClaimServiceCall								;Exit Service Call
}

{
.LA34A	  EQUB &00								;ROM at Banks 0 & 1
	  EQUB &00								;ROM at Banks 2 & 3
	  EQUB &04								;Check for RAM at Banks 4 & 5
	  EQUB &08								;Check for RAM at Banks 6 & 7
	  EQUB &10								;Check for RAM at Banks 8 & 9
	  EQUB &20								;Check for RAM at Banks A & B
	  EQUB &40								;Check for RAM at Banks C & D
	  EQUB &80								;Check for RAM at Banks E & F

;*ROMS Command
.^roms	  LDA #maxBank								;Start at ROM &0F
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
            LDX #userRegRamPresenceFlags						;read RAM installed in bank flag from private &83FF
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            AND LA34A,Y								;Get data from lookup table
            BNE LA380								;Branch if RAM
            LDA #&20								;' '
            BNE LA38D								;jump to write to screen
.LA380      LDX L00AA								;get ROM number
            JSR testRamUsingVariableMainRamSubroutine					;check if ROM is WP. Will return with Z set if writeable
            PHP
            LDA #'E'								;'E' (Enabled)
            PLP
            BEQ LA38D								;jump to write to screen
            LDA #'P'								;'P' (Protected)
.LA38D      JSR OSWRCH								;write to screen
            JSR PrvEn								;switch in private RAM
            LDX L00AA								;Get ROM Number
            LDA romTypeTable,X								;get ROM Type
            LDY #' '								;' '
            AND #&FE								;bit 0 of ROM Type is undefined, so mask out
            BNE LA3BC								;if any other bits set, then ROM exists so skip code for Unplugged ROM check, and get and write ROM details
            LDY #&55								;'U' (Unplugged)
            JSR PrvEn								;switch in private RAM
            LDA prvRomTypeTableCopy,X;								;get backup copy of ROM Type
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
}

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

{
; SFTODO: This only has one caller - probably irrelevant given we also have LA49C entry point
.^createRomBankMaskAndInsertBanks
.LA499      JSR createRomBankMask
;Read ROM Type from ROM header for ROMs with a 1 bit in transientRomBankMask and save to ROM Type Table and Private RAM; used to immediately *INSERT a ROM without waiting for BREAK.
.^insertBanksUsingTransientRomBankMask
.LA49C      JSR PrvEn								;switch in private RAM


            LDY #maxBank
.bankLoop   ASL transientRomBankMask
            ROL transientRomBankMask + 1
            BCC skipBank
            LDA #lo(romType)
            STA osRdRmPtr								;address pointer into paged ROM
            LDA #hi(romType)
            STA osRdRmPtr + 1								;address pointer into paged ROM
            TYA
            PHA
            JSR OSRDRM								;Read ROM Type from paged ROM
            TAX
            PLA
            TAY
            TXA
            STA romTypeTable,Y								;Save ROM Type to ROM Type table
            STA prvRomTypeTableCopy,Y								;Save ROM Type to Private RAM copy of ROM Type table
.skipBank   DEY
            BPL bankLoop
            JSR PrvDis								;switch out private RAM
            RTS
}
			
;Called by *UNPLUG Immediate
;Set bytes in ROM Type Table to 0 for banks with a 0 bit in transientRomBankMask; other banks are not touched.
.unplugBanksUsingTransientRomBankMask
{
.LA4C5      LDY #maxBank
.unplugLoop ASL transientRomBankMask
            ROL transientRomBankMask + 1
            BCS skipBank
            LDA #&00
            STA romTypeTable,Y
.skipBank   DEY
            BPL unplugLoop
            RTS
}
			
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
; SFTODO: This has only one caller
; SFTODO: The OSMODE 2 behaviour seems weird; surely we *don't* have SWR in banks 12-15 (isn't IBOS in bank 15, for a start?), so while this is nominally B+-compatible (although not even that; doesn't the B+ have SWR in banks 0, 1, 12, 13 or something like that?), as soon as any softwre actually tries to work with these banks, won't it break? Maybe I'm missing something...
.assignDefaultPseudoRamBanks
{
.LA4E3      JSR PrvEn								;switch in private RAM
            LDA prvOsMode								;read OSMODE
            LDX #&03								;a total of 4 pseudo banks
            LDY #&07								;for osmodes other than 2, absolute banks are 4..7
            CMP #&02								;check for osmode 2
            BNE notOsMode2
            LDY #maxBank								;if osmode is 2, absolute banks are 12..15
.notOsMode2
.loop	  TYA									;
            STA prvPseudoBankNumbers,X							;assign pseudo bank to the appropriate absolute bank
            DEY									;reduce absolute bank number by 1
            DEX									;reduce pseudo bank number by 1
            BPL loop								;until all 4 pseudo banks have been assigned an appropriate absolute bank
            JMP PrvDis								;switch out private RAM
}

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
			
.^LA513     LDX #userRegBankWriteProtectStatus
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
            JMP ExitAndClaimServiceCall								;Exit Service Call
}

{
.^LA53D      LDX #userRegBankWriteProtectStatus
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            STA prvTmp
            INX
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            PHP
            SEI
            LSR A
            ROR prvTmp
            LSR A
            ROR prvTmp
            ORA #&80
            STA rtcAddress
            LDA prvTmp
            LSR A
            LSR A
            ORA #&40
            STA rtcAddress
            JSR SeiSelectRtcAddressXVariant
            PLP
            RTS
}

;SPOOL/EXEC file closure warning - Service call 10 SFTODO: I *suspect* we are using this as a "part way through reset" service call rather than for its nominal purpose - have a look at OS 1.2 disassembly and see when this is actually generated. Do filing systems or anything issue it during "normal" operation? (e.g. if you do "*EXEC" with no argument.)
{
.^service10 SEC
            JSR SFTODOALARMSOMETHING
            BCS LA570
            JMP softReset ; SFTODO: Rename this label given its use here?
			
.LA570      LDA ramselCopy
            AND #ramselShen
            STA ramselCopy

            JSR PrvEn								;switch in private RAM

            JSR LA53D

;copy ROM type table to Private RAM
            LDX #maxBank
.copyLoop   LDA romTypeTable,X
            STA prvRomTypeTableCopy,X
            DEX
            BPL copyLoop

            JSR PrvDis								;switch out private RAM

            LDX lastBreakType
            BEQ softReset
            LDA #osbyteKeyboardScanFrom10
            JSR OSBYTE
            CPX #keycodeAt
            BNE softReset ; SFTODO: Rename label given use here?
            LDA #&00
            STA L0287
            LDA #&FF
            STA L03A4

	  ; SFTODO: Seems superficially weird we do this ROM type manipulation in response to this particular service call
;Set all bytes in ROM Type Table and Private RAM to 0
            LDX #maxBank
.zeroLoop   CPX romselCopy ; SFTODO: are we confident romselCopy doesn't have b7/b6 set??
            BEQ skipBank
            LDA #&00
            STA romTypeTable,X
            STA romPrivateWorkspaceTable,X
.skipBank   DEX
            BPL zeroLoop

            JMP finish

	  ; SFTODO: Seems superficially weird we do this ROM type manipulation in response to this particular service call
.softReset  LDA #&00
            STA L03A4
            LDX #userRegBankInsertStatus
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            STA transientRomBankMask
            LDX #userRegBankInsertStatus + 1
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            STA transientRomBankMask + 1
            JSR unplugBanksUsingTransientRomBankMask
	  ; SFTODO: Next bit of code is either claiming or not claiming the service call based on prvSFTODOTUBEISH; it will return with A=&10 (this call) or 0.
.finish     LDX #prvSFTODOTUBEISH - prv83
            JSR readPrivateRam8300X							;read data from Private RAM &83xx (Addr = X, Data = A)
            EOR #&FF
            AND #&10
            TSX
            STA L0103,X								;modify stacked A, i.e. A we will return from service call with
            JMP ExitServiceCall								;restore service call parameters and exit
}
			
;Write contents from Private memory address &8000 to screen
.printDateBuffer
{
.LA5DE      LDX #&00
.LA5E0      LDA prvDateBuffer,X
            BEQ LA5EE
            JSR OSASCI
            INX
            CPX prvDateSFTODO1b
            BCC LA5E0
.LA5EE      RTS
}

;store #&05, #&84, #&44 and #&EB to addresses &8220..&8223, but why???
.initDateSFTODOS
{
.LA5EF      LDA #&05
            STA prvDateSFTODO0
            LDA #&84
            STA prvDateSFTODO1 ; SFTODO: b7 of this is tested e.g. at LAD7F
            LDA #&44
            STA prvDateSFTODO2
            LDA #&EB
            STA prvDateSFTODO3
            RTS
}

; Multiply 8-bit values prvA and prvB to give a 16-bit result at prvDC.
.mul8
{
.LA604      LDA #&00
            STA prvDC + 1
            LDX #&08
.loop       ASL A
            ROL prvDC + 1
            ASL prvB
            BCC noAdd
            CLC
            ADC prvA
            BCC noCarry
            INC prvDC + 1
.noCarry
.noAdd      DEX
            BNE loop
            STA prvDC
            RTS
}

; SFTODO: Ignoring the setup, the loop looks very much to me like division of prvA=prvD by prvC, with the result in prvD and the remainder in A. But the setup code says that if prvB (which is otherwise unused)>=prvC, we return with prvD=result=prvA and "remainder" prvB
.SFTODOPSEUDODIV
{
.LA624      LDX #&08
            LDA prvA
            STA prvD
	  LDA prvB
            CMP prvC
            BCS rts ; SFTODO: branch if prvB>=prvC
.loop       ROL prvD
            ROL A
            CMP prvC
            BCC LA640
            SBC prvC
.LA640      DEX
            BNE loop
            ROL prvD
.rts        RTS
}

{
; Read RTC RAM address X into A.
.^ReadRtcRam
    PHP:SEI ; SQUASH: isn't this SEI redundant?
    JSR SeiSelectRtcAddressX
    LDA rtcData
    JSR SeiSelectRtcAddressXVariant
    PLP
    RTS

; Write A to RTC RAM address X.
.^WriteRtcRam
    PHP
    JSR SeiSelectRtcAddressX
    STA rtcData
    JSR SeiSelectRtcAddressXVariant
    PLP
    RTS

.^Nop3
    NOP
.Nop2
    NOP
    NOP
    RTS

.^SeiSelectRtcAddressXVariant ; SFTODO: Be good to clarify why we need this "Variant" - it does leave flags reflecting A, and it is a bit slower, is either of those they key factor?
    PHA
    LDA #&0D ; SFTODO: except for burning two CPU cycles, this seems redundant - note we PHA/PLA and SeiSelectRtcAddressX does not use A - SQUASH: so could we just use NOP and save a byte? Or even get rid of this, given we have other NOPs for (we might hope) delay?
    JSR SeiSelectRtcAddressX
    PLA
    RTS
			
.SeiSelectRtcAddressX
    SEI
    JSR Nop2
    STX rtcAddress
    JMP Nop3 ; SQUASH: could we just move Nop3 here and fall through? But this is hardware and maybe the delay is very precisely calibrated...
}

;Read 'Seconds', 'Minutes' & 'Hours' from Private RAM (&82xx) and write to RTC
; SFTODO: Document this also updates DSE?
.WriteRtcTime
{
    ; Force DV2/1/0 in register A on; this temporarily stops the RTC clock while we set it.
    LDX #rtcRegA:JSR ReadRtcRam:ORA #rtcRegADV2 OR rtcRegADV1 OR rtcRegADV0:JSR WriteRtcRam
    ; Force SET (set mode), DM (binary mode) and 2412 (24 hour mode) on in register B ad
    ; force SQWE (square wave enable) and DSE (auto daylight savings adjust) off.
    LDX #rtcRegB:JSR ReadRtcRam
    AND_NOT rtcRegBSET OR rtcRegBSQWE OR rtcRegBDM OR rtcRegB2412 OR rtcRegBDSE
    ORA #rtcRegBSET OR rtcRegBDM OR rtcRegB2412
    JSR WriteRtcRam
    ; Actually set the time.
    LDX #rtcRegSeconds:LDA prvDateSeconds:JSR WriteRtcRam
    LDX #rtcRegMinutes:LDA prvDateMinutes:JSR WriteRtcRam
    LDX #rtcRegHours:LDA prvDateHours:JSR WriteRtcRam
    ; Clear all bits in register A except DV1; this starts the RTC clock with a 32.768kHz
    ; time-base frequency.
    LDX #rtcRegA:JSR ReadRtcRam:AND #rtcRegADV1:JSR WriteRtcRam
    ; Set DSE in register B according to userRegOsModeShx and force SET off.
    LDX #userRegOsModeShx:JSR readUserReg
    LDX #0
    AND #&10:BEQ NoAutoDSTAdjust ; test auto DST bit of userRegOsModeShx SFTODO: named constant?
    LDX #rtcRegBDSE ; SQUASH: Just do ASSERT rtcRegBDSE == 1:INX
.NoAutoDSTAdjust
    STX prvTmp2
    LDX #rtcRegB:JSR ReadRtcRam
    AND_NOT rtcRegBSET OR rtcRegBDSE
    ORA prvTmp2
    JMP WriteRtcRam
}
			
;Read 'Day of Week', 'Date of Month', 'Month' & 'Year' from Private RAM (&82xx) and write to RTC
.writeRtcDate ; SFTODO: as in "not time" - maybe rename all this later?
{
.LA6CB      JSR waitOutRTCUpdate								;Check if RTC Update in Progress, and wait if necessary
            LDX #rtcRegDayOfWeek							;Select 'Day of Week' register on RTC: Register &06
            LDA prvDateDayOfWeek							;Get 'Day of Week' from &822C
            JSR WriteRtcRam								;Write data from A to RTC memory location X
            INX:ASSERT rtcRegDayOfWeek + 1 == rtcRegDayOfMonth		 		;Select 'Day of Month' register on RTC: Register &07
            LDA prvDateDayOfMonth							;Get 'Day of Month' from &822B
            JSR WriteRtcRam								;Write data from A to RTC memory location X
            INX:ASSERT rtcRegDayOfMonth + 1 == rtcRegMonth					;Select 'Month' register on RTC: Register &08
            LDA prvDateMonth								;Get 'Month' from &822A
            JSR WriteRtcRam								;Write data from A to RTC memory location X
            INX:ASSERT rtcRegMonth + 1 == rtcRegYear					;Select 'Year' register on RTC: Register &09
            LDA prvDateYear								;Get 'Year' from &8229
            JSR WriteRtcRam								;Write data from A to RTC memory location X
            LDX #userRegCentury
            LDA prvDateCentury
            JMP writeUserReg								;Write to RTC clock User area. X=Addr, A=Data
}

;Read 'Seconds', 'Minutes' & 'Hours' from RTC and Store in Private RAM (&82xx)
.getRtcSecondsMinutesHours
{
.LA6F3      JSR waitOutRTCUpdate							;Check if RTC Update in Progress, and wait if necessary
            LDX #rtcRegSeconds							;Select 'Seconds' register on RTC: Register &00
            JSR ReadRtcRam								;Read data from RTC memory location X into A
            STA prvDateSeconds							;Store 'Seconds' at &822F
            LDX #rtcRegMinutes							;Select 'Minutes' register on RTC: Register &02
            JSR ReadRtcRam								;Read data from RTC memory location X into A
            STA prvDateMinutes							;Store 'Minutes' at &822E
            LDX #rtcRegHours								;Select 'Hours' register on RTC: Register &04
            JSR ReadRtcRam								;Read data from RTC memory location X into A
            STA prvDateHours								;Store 'Hours' at &822D
            RTS
}

;Read 'Day of Week', 'Date of Month', 'Month' & 'Year' from RTC and Store in Private RAM (&82xx)
.getRtcDayMonthYear
{
.LA70F      JSR waitOutRTCUpdate							;Check if RTC Update in Progress, and wait if necessary
            LDX #rtcRegDayOfWeek							;Select 'Day of Week' register on RTC: Register &06
            JSR ReadRtcRam								;Read data from RTC memory location X into A
            STA prvDateDayOfWeek							;Store 'Day of Week' at &822C
            INX:ASSERT rtcRegDayOfWeek + 1 == rtcRegDayOfMonth				;Select 'Day of Month' register on RTC: Register &07
            JSR ReadRtcRam								;Read data from RTC memory location X into A
            STA prvDateDayOfMonth							;Store 'Day of Month' at &822B
            INX:ASSERT rtcRegDayOfMonth + 1 == rtcRegMonth					;Select 'Month' register on RTC: Register &08
            JSR ReadRtcRam								;Read data from RTC memory location X into A
            STA prvDateMonth								;Store 'Month' at &822A
            INX:ASSERT rtcRegMonth + 1 == rtcRegYear					;Select 'Year' register on RTC: Register &09
.LA729      JSR ReadRtcRam								;Read data from RTC memory location X into A
            STA prvDateYear								;Store 'Year' at &8229
            JMP defaultPrvDateCentury
}

;Read 'Sec Alarm', 'Min Alarm' & 'Hr Alarm' from RTC and Store in Private RAM (&82xx)
.copyRtcAlarmToPrv
{
.LA732      JSR waitOutRTCUpdate							;Check if RTC Update in Progress, and wait if necessary
            LDX #rtcRegAlarmSeconds							;Select 'Sec Alarm' register on RTC: Register &01
            JSR ReadRtcRam								;Read data from RTC memory location X into A
            STA prvDateSeconds							;Store 'Sec Alarm' at &822F
            LDX #rtcRegAlarmMinutes							;Select 'Min Alarm' register on RTC: Register &03
            JSR ReadRtcRam								;Read data from RTC memory location X into A
            STA prvDateMinutes							;Store 'Min Alarm' at &822E
            LDX #rtcRegAlarmHours							;Select 'Hr Alarm' register on RTC: Register &05
            JSR ReadRtcRam								;Read data from RTC memory location X into A
            STA prvDateHours								;Store 'Hr Alarm' at &822D
            RTS
}

;Read 'Sec Alarm', 'Min Alarm' & 'Hr Alarm' from Private RAM (&82xx) and write to RTC
.copyPrvAlarmToRtc
{
.LA74E      JSR waitOutRTCUpdate								;Check if RTC Update in Progress, and wait if necessary
            LDX #&01								;Select 'Sec Alarm' register on RTC: Register &01
            LDA prvOswordBlockCopy + 15								;Get 'Sec Alarm' from &822F
            JSR WriteRtcRam								;Write data from A to RTC memory location X
            LDX #&03								;Select 'Min Alarm' register on RTC: Register &03
            LDA prvOswordBlockCopy + 14								;Get 'Min Alarm' from &822E
            JSR WriteRtcRam								;Write data from A to RTC memory location X
            LDX #&05								;Select 'Hr Alarm' register on RTC: Register &05
            LDA prvOswordBlockCopy + 13								;Get 'Hr Alarm' from &822D
            JMP WriteRtcRam								;Write data from A to RTC memory location X
}

.getRtcDateTime
{
.LA769      JSR getRtcDayMonthYear
            JMP getRtcSecondsMinutesHours
}

; SFTODO: Following block is dead code
{
            JSR WriteRtcTime								;Read 'Seconds', 'Minutes' & 'Hours' from Private RAM (&82xx) and write to RTC						***not used. nothing jumps into this code***
            JMP writeRtcDate								;Read 'Day of Week', 'Date of Month', 'Month' & 'Year' from Private RAM (&82xx) and write to RTC
}

;Wait until RTC Update in Progress	is complete
.waitOutRTCUpdate
{
    LDX #rtcRegA
.loop
    JSR Nop3								;3 x NOP delay
    STX rtcAddress								;Strobe in address
    JSR Nop3								;3 x NOP delay
    ASSERT rtcRegAUIP == &80
    LDA rtcData
    BMI loop ; try again if update in progress
    RTS
}

{
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
.^LA790      LDX #rtcRegB								;Select 'Register B' register on RTC: Register &0B
            LDA #&86								;Stop Clock, Set Binary mode, Set 24hr mode
            JSR WriteRtcRam								;Write data from A to RTC memory location X
            DEX									;Select 'Register A' register on RTC: Register &0A
            LDA #&E0								;Divider Off, Invalid write 'Update in Progress' bit!
            JSR WriteRtcRam								;Write data from A to RTC memory location X
            DEX									;Start at Register &09
.LA79E      LDA LA786,X								;Read data from table
            JSR WriteRtcRam								;Write data from A to RTC memory location X
            DEX									;Next register
            BPL LA79E								;Until <0
            RTS									;Exit
}

.SFTODOALARMSOMETHING
{
.LA7A8      BCS LA7C2
            LDX #userRegAlarm
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            AND #&40
            LSR A
            STA L00AE
            LDX #&0B								;Select 'Register B' register on RTC: Register &0B
            JSR ReadRtcRam								;Read data from RTC memory location X into A
            ORA #&08
            ORA L00AE
            JSR WriteRtcRam								;Write data from A to RTC memory location X
.clcRts      CLC
            RTS

.LA7C2      LDX #&0B								;Select 'Register B' register on RTC: Register &0B
            JSR ReadRtcRam								;Read data from RTC memory location X into A
            AND #&08
            BNE clcRts
            SEC
            RTS

; Return with C set iff prvDate{Century,Year} is a leap year.
.^testLeapYear
.LA7CD      LDA prvDateYear
            CMP #&00 ; SFTODO: redundant
            BNE notYear0
            LDA prvDateCentury
.notYear0   LSR A									;Test divisibility of A by 4
            BCS clcRts
            LSR A
            BCS clcRts
            SEC
            RTS
}

.getDaysInMonthY
{
.LA7DF      DEY ; SFTODO: We could avoid this DEY/INY if we changed next line to LDA monthDaysTable-1,Y
            LDA monthDaysTable,Y
            INY
            CPY #2									;February
            BNE rts
            PHA
            JSR testLeapYear
            PLA
            BCC rts
            LDA #29
.rts        RTS

;Lookup table for Number of Days in each month
.monthDaysTable
        	  EQUB 31 ; January
	  EQUB 28 ; February
	  EQUB 31 ; March
	  EQUB 30 ; April
	  EQUB 31 ; May
	  EQUB 30 ; June
	  EQUB 31 ; July
	  EQUB 31 ; August
	  EQUB 30 ; September
	  EQUB 31 ; October
	  EQUB 30 ; November
	  EQUB 31 ; December
}

; SFTODO: This has only one caller
; SFTODO: This seems to want to calculate "prvDate - 1st January in same year" in days, so result (in prvDateSFTODO4, 16 bit word) will be 0 for 1st January, 1 for 2nd January, etc. However, see the comment below about TYA vs TXA - what it actually seems to do is return the number of days up to the end of prvMonth in prvDateSFTODO4 and prvDateDayOfMonth-1 in X. Maybe this *is* what it really wants to do and I'm misinterpreting things - would need to look at caller in more detail
.calculateDaysBetween1stJanAndPrvDateSFTODOIsh
{
.LA7FE      LDA #&00
            STA prvDateSFTODO4
            STA prvDateSFTODO4 + 1
            LDY #0
.LA808      INY
            CPY prvDateMonth
            BEQ LA823
            JSR getDaysInMonthY
            CLC
            ADC prvDateSFTODO4
            STA prvDateSFTODO4
	  ; SFTODO: Could use BCC:INC to save a few bytes
            LDA prvDateSFTODO4 + 1
            ADC #0
            STA prvDateSFTODO4 + 1
            BCC LA808 ; SFTODO: In reality won't this branch always be taken? We're counting days from 1st January and we surely won't overflow a 16-bit word?
            RTS ; SFTODO: In which case this is redundant

.LA823      LDX prvDateDayOfMonth
            DEX
            TYA ; SFTODO: should this be TXA?? Pretty sure it should, see test/date.bas
            CLC
            ADC prvDateSFTODO4
            STA prvDateSFTODO4
	  ; SFTODO: Could use BCC:INC to save a few bytes
            LDA prvDateSFTODO4 + 1
            ADC #0
            STA prvDateSFTODO4 + 1
            RTS
}

{
; SFTODO: Both of these return with bits set in prvDateSFTODO0 for errors - does anything actually check this except to see if it's 0/non-0?
; SFTODO: This entry point validates days in February based on prvDate{Century,Year}
; SFTODO: Bits in pprvDateSFTODO0 are set to indicate errors: SFTODO: maybe have named constants for these bits
;    b7: century
;    b6: year
;    b5: month
;    b4: day of month
;    b3: day of week
;    b2: hours
;    b1: minutes
;    b0: seconds
.^validateDateTimeRespectingLeapYears
.LA838      CLC
            BCC LA83C
; SFTODO: This entry point always allows 29th February regardless
.^validateDateTimeAssumingLeapYear ; SFTODO: perhaps not ideal name
.LA83B      SEC
.LA83C      PHP
            LDA prvDateCentury
            LDX #0
            LDY #99
            JSR checkABetweenXAndY
            LDA #&80 ; SFTODO: Does anything actually check the individual bits in the result we build up? If not this code could potentially be simplified.
            JSR recordCheckResultForA
            LDA prvDateYear
            LDX #0
            LDY #99
            JSR checkABetweenXAndY
            LDA #&40
            JSR recordCheckResultForA
            LDA prvDateMonth
            LDX #1
            LDY #12
            JSR checkABetweenXAndY
            LDA #&20
            JSR recordCheckResultForA
            PLP
            BCC lookupMonthDays
            LDA prvDateMonth
            CMP #&FF ; SFTODO: why would we have &FF in month? Not saying we can't, just superficially odd without having been over all code yet...
            BNE haveMonth
            LDY #31 ; if we can't tell what month, err on the side of caution.
            BNE monthDaysInY ; always branch
.haveMonth  CMP #2 									; February
            BNE lookupMonthDays
            LDY #29
            BNE monthDaysInY ; always branch
.lookupMonthDays
	  LDY prvDateMonth
            JSR getDaysInMonthY
            TAY
.monthDaysInY
	  LDA prvDateDayOfMonth
            LDX #1
            JSR checkABetweenXAndY
            LDA #&10
            JSR recordCheckResultForA
            LDA prvDateDayOfWeek
            LDX #&00
            LDY #&07
            JSR checkABetweenXAndY
            LDA #&08
            JSR recordCheckResultForA
            LDA prvDateHours
            LDX #&00
            LDY #&17
            JSR checkABetweenXAndY
            LDA #&04
            JSR recordCheckResultForA
            LDA prvDateMinutes
            LDX #&00
            LDY #&3B
            JSR checkABetweenXAndY
            LDA #&02
            JSR recordCheckResultForA
            LDA prvDateSeconds
            JSR checkABetweenXAndY
            LDA #&01
; Set the bits set in A in prvOswordBlock if C is set, clear them if C is clear.
.recordCheckResultForA
	  BCC recordOk ; SFTODO: could we just BCC rts if we knew prvDateSFTODO0 was 0 to start with? Do we re-use A values?
            ORA prvDateSFTODO0
            STA prvDateSFTODO0
            RTS
.recordOk   EOR #&FF
            AND prvDateSFTODO0
            STA prvDateSFTODO0
            RTS

; Return with C clear iff X<=A<=Y.
.checkABetweenXAndY
	  STA prvTmp2
            CPY prvTmp2
            BCC secRts
            STX prvTmp2
            CMP prvTmp2
            BCC secRts ; SFTODO: Any chance of using another copy of these instructions?
            CLC
            RTS
.secRts     SEC
            RTS
}

; SFTODO: The following block is dead code
{
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
}

; SFTODO: the "in" in the next two exported labels is maybe confusing, "storeTo" might be better but even more longwinded - anyway, just a note for when I finally clean up all the label names
{
; As calculateDayOfWeekInA, except we also update prvDateDayOfWeek with the calculated day of the week, and set SFTODO:PROBABLY b3 of prvDateSFTODO0 if this changes prvDateDayOfWeek from its previous value.
.^calculateDayOfWeekInPrvDateDayOfWeek
.LA905      CLC
            BCC LA909
; SFTODO: Use a magic formula to calculate the day of the week for prvDate{Century,Year,Month,DayOfMonth}; I don't know how this works, but presumably it does.
; We return with the calculated day of the week in A.
.^calculateDayOfWeekInA
.LA908      SEC
.LA909      PHP
            LDA prvDateYear
            STA prvTmp3
            LDA prvDateCentury
            STA prvTmp2
	  ; SFTODO: We seem to be decrementing the date by one month here, there is a general "if this goes negative, borrow from the next highest unit" quality. I'm not entirely clear why we start off with SBC #2, maybe we are decrementing by two months, or maybe we are switching to some kind of start-in-March system, complete guesswork in that respect.
            SEC
            LDA prvDateMonth
            SBC #2
            STA prvTmp4
            BMI january ; SFTODO? I think this is right
            CMP #1
            BCS decrementDone ; branch if March or later month?
.january    CLC
            ADC #12 ; SFTODO: so we now have original month plus 10??
            STA prvTmp4
            DEC prvTmp3
            BPL decrementDone ; branch if wasn't year 0
            CLC
            LDA prvTmp3 ; SFTODO: don't we know this is 255 in practice and thus the ADC #100 will always give us A=99?
            ADC #100
            STA prvTmp3
            DEC prvTmp2
            BPL decrementDone
            CLC
            LDA prvTmp2
            ADC #100
            STA prvTmp2
.decrementDone ; SFTODO: rename to "noBorrow"?
            LDA prvTmp4
            STA prvA
            LDA #130
            STA prvB
            JSR mul8 ; DC=A*B
            ASL prvDC
            ROL prvDC + 1
            SEC
            LDA prvDC
            SBC #19
            STA prvA
            LDA prvDC + 1
            SBC #&00
            STA prvB
	  ; SFTODO: So BA=prvTmp4*130-19??
            LDA #100
            STA prvDC
            JSR SFTODOPSEUDODIV
            CLC
            LDA prvDC + 1
            ADC prvDateDayOfMonth
            ADC prvTmp3
.LA97E      STA prv82+&4A
            LDA prvTmp3
            LSR A
            LSR A
            CLC
            ADC prvA
            STA prvA
            LDA prvTmp2
            LSR A
            LSR A
            CLC
            ADC prvA
            ASL prvTmp2
            SEC
            SBC prvTmp2
            PHP
            BCS LA9A5
            SEC
            SBC #&01
            EOR #&FF
.LA9A5      STA prvA
            LDA #&00
            STA prvB
            LDA #&07
            STA prvC
            JSR SFTODOPSEUDODIV
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
.LA9C6      STA prvA
            INC prvA
            LDA prvA
            PLP ; get stacked flags from entry
            BCS rts
            CMP prvDateDayOfWeek
            BEQ LA9DF
            LDA #&08 ; SFTODO: This bit is the same one validateDateTimeRespectingLeapYear uses to indicate day of week invalid, but the meaning of SFTODO0 seems to change a bit and I'm not entirely sure I am interpreting this correctly
            ORA prvDateSFTODO0
            STA prvDateSFTODO0
.LA9DF      LDA prvA
            STA prvDateDayOfWeek
.rts        RTS
}

; SFTODOWIP
; SFTODO: This description is a bit of a guess, but I think it's a fairly good one
; We output month calendars with 7 rows for Sun-Sat and up to 6 columns; to see 6 columns may be needed, consider a 31-day month where 1st is a Saturday. Populate the buffer pointed to by prvDateSFTODO4 so elements 0-6 are the day numbers to display in row 0 (the day numbers of the Sundays), elements 7-13 are the day numbers to dispay in row 1 (the day numbers of the Mondays), etc, for a total of 6*7=42 elements. Blank cells have day number 0.
.generateInternalCalendar
{
; SFTODO: 7 ROWS, 6 COLUMNS ARE KEY NUMBERS HERE AND WE SHOULD PROBABLY BE CALCULATING SOME NAMED CONSTANTS (EG 42) FROM OTHER NAMED CONSTANTS WHICH ARE 6 AND 7
daysInMonth = transientDateSFTODO2
.LA9E6      LDA #1
            STA prvDateDayOfMonth
            JSR calculateDayOfWeekInPrvDateDayOfWeek
            LDY prvDateMonth
            JSR getDaysInMonthY
            STA daysInMonth
.makePrvDateDayOfWeekGe37Loop
            CLC
            LDA daysInMonth
            ADC prvDateDayOfWeek
            CMP #37
            BCS prvDateDayOfWeekGe37
            CLC
            LDA prvDateDayOfWeek
            ADC #7
            STA prvDateDayOfWeek
            JMP makePrvDateDayOfWeekGe37Loop
.prvDateDayOfWeekGe37
            LDA prvDateSFTODO4
            STA transientDateSFTODO1
            LDA prvDateSFTODO4 + 1
            STA transientDateSFTODO1 + 1
            LDA #0
            LDY #42
.zeroBufferLoop
	  DEY
            STA (transientDateSFTODO1),Y
            BNE zeroBufferLoop
            INC daysInMonth ; bump daysInMonth so the following loop can use a strictly less than comparison
.dayOfMonthLoop
            LDA prvDateDayOfMonth
            CMP daysInMonth
            BCC notDone ; SFTODO: Could we BCS to a nearby RTS (there's one just above) to save a byte
            RTS
.notDone    ADC prvDateDayOfWeek
            SEC
            SBC #&02
            STA prvA
            LDA #&00
            STA prvB
            LDA #&07
            STA prvC
            JSR SFTODOPSEUDODIV
            STA prvA ; SFTODO: Ignoring SFTODOPSEUDODIV quirk with prvB, we are setting A = (prvDateDayOfWeek + 2) MOD 7 - though remember we adjusted prvDateDayOfWeek above for currently unclear reasons (I suspect they're something to do with blanks in the first column of dates, ish)
            LDA #&06
            STA prvB
            LDA prvD ; SFTODO: stash result of pseudo-division as mul8 will corrupt prvD
            PHA
            JSR mul8 ; SFTODO: prvDC = 6 * the A we calculated above
            PLA
            CLC
            ADC prvC ; SFTODO: add the stashed pseudo-division result to the low byte of the multiplication we just did (we *probably* know the high byte in prvD is zero and can be ignored)
            TAY
            LDA prvDateDayOfMonth
            STA (transientDateSFTODO1),Y ; SFTODO: I think what we're doing here is putting the day-of-month numbers into the order we need to output them a line at a time (although the exact nature of how we're doing that via the above calculations isn't completely clear yet)
            INC prvDateDayOfMonth
            JMP dayOfMonthLoop
}

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
.calOffsetTable	EQUB &00,&05,&0B,&11,&18,&21,&29,&2F
		EQUB &37,&3E,&46,&4B,&50,&53,&57,&5B
		EQUB &61,&6A,&71,&79,&81


;&824E=calText pointer for next month / day
;&824F=Capitalisation mask (&DF or &FF)			
;&8250=calOffset pointer
;On Month Entry:		Carry Set,   A=01-12 (Jan-Dec)
;On Day of Week Entry:	Carry Clear, A=01-07 (Sun-Sat)
; SFTODO: X on entry is maximum number of characters to print? (0 means 256, i.e. effectively unlimited)
; SFTODO: Y has some significance on entry (Y=0 => capitalise first letter, otherwise all lower case)
.emitDayOrMonthName
{
endCalOffset = prv82 + &4E
capitalisationMask = prv82 + &4F
maxOutputLength = prv82 + &50 ; SFTODO: rename this, I think it's "max chars to print"
.LAAF5	  BCC indexInA
	  CLC
            ADC #&07								;adjust month index to skip past the day of week entries in calOffsetTable
.indexInA   STX maxOutputLength
            CPY #&00								;First letter? SFTODO: Seems a little odd, given we LDY transientDataBufferIndex *below*
            BNE initCapitalisationMask							;No? Then branch
            LDY #&DF								;Load capitalise mask
            STY capitalisationMask							;Save mask to &824F
            JMP capitalisationMaskSet ; SFTODO: We could BNE ; always
.initCapitalisationMask
            LDY #&FF								;otherwise no capitalise
            STY capitalisationMask							;save mask to &824F
.capitalisationMaskSet
            TAX
            INX
            LDA calOffsetTable,X							;get calText offset for next month / day
            STA endCalOffset								;save calText offset for next month / day to &824E
            DEX
            LDA calOffsetTable,X							;get calText offset for current month / day
            TAX									;move calText offset for current month / day to X
            LDY transientDateBufferIndex						;get buffer pointer
            LDA calText,X								;get first letter
            AND #&DF								;capitalise this letter
            JMP charInA
			
.loop       LDA calText,X								;get subsequent letters
            AND capitalisationMask							;apply capitalisation mask
.charInA    STA (transientDateBufferPtr),Y						;store at buffer &XY?Y
            INY									;increase buffer pointer
            INX									;increment calText offset for current month / day
            DEC maxOutputLength							;don't output more than (initial) maxOutputLength characters
            BEQ done
            CPX endCalOffset								;reached the calText offset for next month / day?
            BNE loop 								;no? loop.
.done       STY transientDateBufferIndex						;save buffer pointer
            RTS
}
			
{
tensChar = prv82 + &4E
unitsChar = prv82 + &4F

; Emit A (<=99) into transientDateBuffer, formatted as a decimal number according to X:
;   A    0     5     25
; X=0 => "00"  "05"  "25"	Right-aligned in a two character field with leading 0s
; X=1 => "0"   "5"   "25"	Left-aligned with no padding, 1 or 2 characters
; X=2 => " 0"  " 5"  "25"	Right-aligned in a two character field with no leading 0s
; X=3 => "  "  " 5"  "25"	Right-aligned in a two character field with no leading 0s, 0 shown as blank
.^emitADecimalFormatted ; SFTODO: should have ToDateBuffer in name
.LAB3C      JSR convertAToTensUnitsChars						;Split number in register A into 10s and 1s, characterise and store units in &824F and 10s in &824E
            LDY transientDateBufferIndex						;get buffer pointer
.LAB41      CPX #&00
            BEQ printTensChar
            LDA tensChar								;get 10s
            CMP #'0'								;is it '0'
            BNE printTensChar
            CPX #&01	
            BEQ skipLeadingZero
            LDA #' '								;convert '0' to ' '
            STA tensChar								;and save to &824E
            LDA unitsChar								;get 1s
            CMP #'0'								;is it '0'
            BNE printTensChar
            CPX #&03
            BNE printTensChar
            LDA #' '								;convert '0' to ' '
            STA unitsChar								;and save to &824F
.printTensChar
	  LDA tensChar								;get 10s
            STA (transientDateBufferPtr),Y						;store at buffer &XY?Y
            INY									;increase buffer pointer
.skipLeadingZero
            LDA unitsChar								;get 1s
            JMP emitAToDateBufferUsingY							;store at buffer &XY?Y, increase buffer pointer, save buffer pointer and return.

;postfix for dates. eg 25th, 1st, 2nd, 3rd
.dateSuffixes
	  EQUS "th", "st", "nd", "rd"

; Emit ordinal suffix for A (<=99) into transientDateBuffer; if C is set it will be capitalised.
; SFTODO: This only has one caller, can it just be inlined?
.^emitOrdinalSuffix
.LAB79      PHP									;save carry flag. Used to select capitalisation
            JSR convertAToTensUnitsChars						;Split number in register A into 10s and 1s, characterise and store units in &824F and 10s in &824E
            LDA tensChar								;get 10s
            CMP #'1'								;check for '1'
            BNE not1x								;branch if not 1.
.thSuffix   LDX #&00								;if the number is in 10s, then always 'th'
            JMP suffixInX ; SFTODO: Could BEQ ; always
			
.not1x      LDA unitsChar								;get 1s
            CMP #'4'								;check if '4'
            BCS thSuffix								;branch if >='4'
            AND #&0F								;mask lower 4 bits, converting ASCII digit to binary
            ASL A									;x2 - 1 becomes 2, 2 becomes 4, 3 becomes 6
            TAX
.suffixInX  PLP									;restore carry flag. Used to select capitalisation
            LDY transientDateBufferIndex						;get buffer pointer
            LDA dateSuffixes,X							;get 1st character from table + offset
            BCC noCaps1								;don't capitalise
            AND #&DF								;capitalise
.noCaps1    STA (transientDateBufferPtr),Y						;store at buffer &XY?Y
            INY									;increase buffer pointer
            LDA dateSuffixes+1,X							;get 2nd character from table + offset
            BCC noCaps2								;don't capitalise
            AND #&DF								;capitalise
.noCaps2    JMP emitAToDateBufferUsingY							;store at buffer &XY?Y, increase buffer pointer, save buffer pointer and return

;Split number in register A into 10s and 1s, characterise and store 1s in &824F and 10s in &824E
.convertAToTensUnitsChars
            LDY #&FF
            SEC
.tensLoop   INY									;starting at 0
            SBC #10
            BCS tensLoop								;count 10s till negative. Total 10s stored in Y
            ADC #10									;restore last subtract to get positive again. This gets the units
            ORA #'0'								;convert units to character
            STA unitsChar								;save units to &824F
            TYA									;get 10s
            ORA #'0'								;convert 10s to character
            STA tensChar								;save 10s to &824F
            RTS
}

{
.timeSuffixes
	  EQUS "am", "pm"

; Emit time suffix for hour A (<=23) into transientDateBuffer.
; SFTODO: This only has one caller, could it just be inlined?
.^emitTimeSuffixForA
.LABC5      TAX
            CPX #&00								;is it 00 hrs?
            BNE not0Hours								;branch if not 00 hrs
            LDX #24 								;else set X=24 (hrs)
.not0Hours  LDA #&00
            CPX #13 								;carry set if X>=13 (hrs) ('pm')
            ADC #&00								;otherwise ('am')
            ASL A									;x2 - A=0 ('am') or A=2 ('pm')
            TAX
            LDY transientDateBufferIndex						;get buffer pointer
            LDA timeSuffixes,X							;get 'a' or 'p'
            STA (transientDateBufferPtr),Y						;save contents of A to Buffer Address+Y
            INY									;increase buffer pointer
            LDA timeSuffixes + 1,X							;get 'm'
            JMP emitAToDateBufferUsingY							;store at buffer &XY?Y, increase buffer pointer, save buffer pointer and return
}

IF FALSE
; SFTODO: emitTimeSuffixForA is a bit more complex than necessary - here's a shorter alternative implementation, not tested!
.emitTimeSuffixForA
{
	LDX #'a'
	TAY:BEQ suffixInX 								;branch if 00 hrs ('am')
	CMP #13
	BCC suffixInX								;branch if A<13 (hrs) ('am')
	LDX #'p'									;('pm')
.suffixInX
	TXA:JSR emitAToDateBuffer
	LDA #'m':FALLTHROUGH_TO emitAToDateBuffer
}
ENDIF
			
;&AA stores the buffer address offset
;&00A8 stores the address of buffer address
;this code saves the contents of A to buffer address + buffer address offset
{
.^emitAToDateBuffer
.LABE2      LDY transientDateBufferIndex								;read buffer pointer
.^emitAToDateBufferUsingY
.LABE4      STA (transientDateBufferPtr),Y								;save contents of A to Buffer Address+Y
            INY									;increase buffer pointer
            STY transientDateBufferIndex								;save buffer pointer
            RTS
}

; SFTODOWIP
; SFTODOWIP COMMENT
; This roughly emits "<hour><minute><second><time suffix>"
; prvDateSFTODO2:
;     b0..3: 0 => return with C set
;            <4 => don't emit hour or time suffix
;            b2 clear => X=2, b2 set => X=0 for formatting hour
;            b0 clear => use 24h time
;            >4 or 1 => emit minutes using format X=0, otherwise use format X=n
;            <8 => use ':' after minute
;            <12 (and >=8) => don't emit seconds
;	   >=12 => use '/' after minute
; Normal return has C clear
.emitTimeToDateBuffer ; SFTODO: "time" as in "hour/min/sec, not day of month etc"
{
.LABEA      LDA prvDateSFTODO2								;&44 for OSWORD 0E
            AND #&0F								;&04 for OSWORD 0E
            STA transientDateSFTODO1
            BNE LABF5
            SEC
            RTS
			
.LABF5      LDA transientDateSFTODO1
            CMP #&04
            BCC SFTODOSTEP2MAYBE								;branch if <4
            LDX #&00
            AND #&02
            EOR #&02
            BNE LAC05
            INX
            INX
.LAC05      LDA transientDateSFTODO1
            AND #&01
            PHP
            LDA prvDateHours								;read Hours
            PLP
            BEQ hoursInA
            LDA prvDateHours								;read Hours
            BEQ zeroHours								;check for 00hrs. If so, convert to 12
            CMP #13 								;
            BCC hoursInA								;check for 13hrs and above
            SBC #12 								;if so, subtract 12
            BCS hoursInA
.zeroHours  LDA #12									;12am
.hoursInA   JSR emitADecimalFormatted							;convert to characters, store in buffer XY?Y, increase buffer pointer, save buffer pointer and return
            LDA #':'
            JSR emitAToDateBuffer							;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
.SFTODOSTEP2MAYBE      LDX #&00
            LDA transientDateSFTODO1
            CMP #&04
            BCS LAC34								;branch if >=4
            CMP #&01
            BEQ LAC34								;branch if =1
            TAX
.LAC34      LDA prvDateMinutes							;read Minutes
            JSR emitADecimalFormatted							;convert to characters, store in buffer XY?Y, increase buffer pointer, save buffer pointer and return
            LDA transientDateSFTODO1
            CMP #&08
            BCC separatorColon
            CMP #&0C
            BCC SFTODOMAYBESTEP3
            LDA #'/'
            BNE separatorInA ; always branch
.separatorColon
	  LDA #':'
.separatorInA
	  JSR emitAToDateBuffer							;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
            LDX #&00
            LDA prvDateSeconds							;read seconds
            JSR emitADecimalFormatted							;convert to characters, store in buffer XY?Y, increase buffer pointer, save buffer pointer and return
.SFTODOMAYBESTEP3      LDA transientDateSFTODO1
            CMP #&04
            BCC LAC6C
            LDA transientDateSFTODO1
            AND #&01
            BEQ LAC6C
            LDA #' '
            JSR emitAToDateBuffer							;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
            LDA prvDateHours								;read hours
            JSR emitTimeSuffixForA								;write am / pm to
.LAC6C      CLC
            RTS
}

;Separators for Time Display? SFTODO: seems probable, need to update this comment when it becomes clear
.dateSeparators ; SFTODO: using "date" for consistency with prvDate* variables, maybe revisit after - all the "time"/"date"/"calendar" stuff has a lot of common code
{
.LAC6E		EQUS " ", "/", ".", "-"
}

; SFTODO WIP COMMENTS
; On entry prvDateSFTODO2 is &ab
;     if a != 0:
;         Y=(!a) & 1 - this controls capitalisation in emit day name, so b0 of a controls that
;         emit day name using (roughly) a characters max
;	stop if prvDateSFTODO3 is 0
;         if b >= 4:
;             print ","
;	if b < 4 or b > 8:
;             print " "
;     (now at SFTODOSTEP2)
;
; Roughly speaking this is emitting a string of the form "<day of week><day of month><month><century><year>"; the actual format of each of those elements, including whether they are just zero length strings and what punctuation they have, is controlled by prvDateSFTODO*.
; SFTODO: Is this extremely "compact" representation mandated by some API? Given our relatively large amount of private workspace in our private RAM, I can't help suspecting we could use whole bytes for some of these bitfields and substantially shrink the code. I may be wrong about that.
;
; prvDateSFTODO1:
;    b0..1: dateSeparators[n] to emit after day of month/month
;
; prvDateSFTODO2:
;    b4..7: 0 => don't emit day of week
;           >=5 => don't truncate day of week
;           >=3 (but <5) => truncate day of week to 3 characters
;           <3 => truncate day of week to n-1 characters
;
;    b4: 1 => capitalise day of week, 0=> don't capitalise day of week
;
; prvDateSFTODO3:
;     0 => emit just day of week
;     b0..2: 0 => don't emit day of month
;            >=4 => emit day of month using X=1
;            3 => emit day of month using X=0
;            0/1 => emit day of X using X=0/1
;
;            <4 => don't emit ordinal suffix for day of month
;            4 => emit capitalised ordinal suffix for day of month
;            >4 => emit uncapitalised ordinal suffix for day of month
;     b3..7: 0 => don't emit anything after day of month
;     b3   : 0 => capitalise month name, 1=> don't capitalise month name
;     b3..5: 0 => don't emit month
;            >=4 =>
;	       >=6 => emit month as name truncated to 3 characters
;                <6  => emit month as name without truncation
;            <4 => emit month as formatted decimal in mode X, where X=0 if n==3 else n
;     b6..7: 0 => don't emit anything after month
;            b7: 0 => don't emit century, 1 => emit century
;            b6: (if century is emitted) 0 => emit "'" as century 1=> emit century as two digit number
.emitDateToDateBuffer ; SFTODO: "date" here as in "the day identifier, omitting any time indicator within that day"
{
.LAC72
; SFTODO: Experimentally using nested scopes here to try to make things clearer, by making it more obvious that some labels have restricted scope - not sure if this is really helpful, let's see
; SFTODO: Chopping the individual blocks up into macros might make things clearer?
; 1. Optionally emit the day of the week, optionally truncated and/or capitalised, and optionally followed by some punctuation. prvDataSFTODO2's high nybble controls most of those options, although prvDataSFTODO3=0 will prevent punctuation and cause an early return.
    {
	  LDA prvDateSFTODO2
	  ; SFTODO: Use lsrA4
            LSR A
            LSR A
            LSR A
            LSR A
            STA transientDateSFTODO1
            BEQ SFTODOSTEP2
            AND #&01
            EOR #&01
            TAY
            LDA transientDateSFTODO1
            LDX #&00
            CMP #&05
            BCS maxCharsInX
            LDX #&03
            CMP #&03
            BCS maxCharsInX
            DEX
.maxCharsInX
	  LDA prvDateDayOfWeek							;get day of week
            CLC									;Carry Set=Month, Clear=Day of Week
            JSR emitDayOrMonthName							;X is maximum number of characters to emit, Y controls capitalisation
            LDA prvDateSFTODO3
            BNE LACA0
            JMP LAD5Arts

.LACA0      LDA prvDateSFTODO1
            AND #&0F
            STA transientDateSFTODO1
            CMP #&04
            BCC LACB6
            LDA #','
            JSR emitAToDateBuffer							;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
            LDA transientDateSFTODO1
            CMP #&08
            BCC SFTODOSTEP2
.LACB6      LDA #' '
            JSR emitAToDateBuffer							;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
    }
.SFTODOSTEP2
    {
; 2. Optionally print the day of the month with optional formatting/capitalisation. Options controlled by b0-2 of prvDateSFTODO3. If b3-7 of prvDateSFTODO3 are zero we return early. Otherwise we output dataSeparators[b0-2 of prvDataSFTODO1].
            LDA prvDateSFTODO3
            AND #&07
            STA transientDateSFTODO1
            BEQ SFTODOSTEP3MAYBE
            LDX #&01
            CMP #&04
            BCS LACD0
            DEX
            CMP #&03
            BEQ LACD0
            TAX
.LACD0      LDA prvDateDayOfMonth							;read Day of Month
            JSR emitADecimalFormatted							;X controls formatting
            LDA transientDateSFTODO1
            CMP #&04
            BCC LACE5
            BEQ LACDF
            CLC									;don't capitalise
.LACDF      LDA prvDateDayOfMonth							;Get Day of Month from RTC
            JSR emitOrdinalSuffix							;Convert to text, then save to buffer XY?Y, increment buffer address offset.
.LACE5      LDA prvDateSFTODO3
            AND #&F8
            BEQ LAD5Arts
            LDA prvDateSFTODO1
            AND #&03								;mask lower 3 bits
            TAX
            LDA dateSeparators,X							;get character from look up table
            JSR emitAToDateBuffer							;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
    }
; 3. Look at b3-5 of prvDateSFTODO3; if they're 0, jump to step 4. Otherwise emit the month with optional formatting. Then stop if b5-6 of prvDateSFTODO3 are 0. Otherwise emit a dateSeparator based on low two bits of prvDateSFTODO1.
.SFTODOSTEP3MAYBE
    {
	  LDA prvDateSFTODO3
            LSR A
            LSR A
            LSR A
            AND #&07
            STA transientDateSFTODO1
            BEQ SFTODOSTEP4MAYBE
            CMP #&04
            BCS LAD18
            LDX #&00
            CMP #&03
            BEQ formatInX
            TAX
.formatInX  LDA prvDateMonth								;read month
            JSR emitADecimalFormatted							;X controls formatting
            JMP LAD2A

.LAD18      LDX #&03
            CMP #&06
            BCC LAD20
            LDX #&00
.LAD20      AND #&01
            TAY
            LDA prvDateMonth								;Get Month
            SEC									;Carry Set=Month, Clear=Day of Week
            JSR emitDayOrMonthName							;X is max characters to emit, Y controls capitalisation
.LAD2A      LDA prvDateSFTODO3
            AND #&C0
            BEQ LAD5Arts
            LDA prvDateSFTODO1
            AND #&03								;mask lower 3 bits
            TAX
            LDA dateSeparators,X								;get character from look up table
            JSR emitAToDateBuffer								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
    }
.SFTODOSTEP4MAYBE ; SFTODO: THESE STEP N LABELS SHOULD BE CHANGED TO REFLECT THINGS LIKE DAYOFWEEK, DAY, MONTH
    {
	  LDA prvDateSFTODO3
            AND #&C0
            BEQ LAD5Arts
            CMP #&80
            BCC emitYear
            BEQ emitCenturyTick
            LDX #&00
            LDA prvDateCentury								;read century
            JSR emitADecimalFormatted								;convert to characters, store in buffer XY?Y, increase buffer pointer, save buffer pointer and return
.emitYear   LDX #&00
            LDA prvDateYear								;read year
            JMP emitADecimalFormatted								;convert to characters, store in buffer XY?Y, increase buffer pointer, save buffer pointer and return
			
.^LAD5Arts      RTS

.emitCenturyTick
	  LDA #'''								;'''
            JSR emitAToDateBuffer								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
            JMP emitYear
    }
}
			

;read buffer address from &8224 and store at &A8
;set buffer pointer to 0
.initDateBufferAndEmitTimeAndDate
{
.LAD63      LDA prvDateSFTODO4							;get OSWORD X register (lookup table LSB) SFTODO: not sure this comment is always true, e.g. we can be called via *TIME
            STA transientDateBufferPtr							;and save
            LDA prvDateSFTODO4 + 1							;get OSWORD Y register (lookup table MSB) SFTODO: ditto
            STA transientDateBufferPtr + 1						;and save
            LDA #&00
            STA transientDateBufferIndex						;set buffer pointer to 0
            JSR emitTimeAndDateToDateBuffer
            LDA #vduCr
            JSR emitAToDateBuffer							;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
            LDY transientDateBufferIndex						;get buffer pointer
            STY prvDateSFTODO1b
.^LAD7Erts     RTS

; SFTODO: Next line implies b7 of prvDateSFTODO1 "mainly" controls ordering
.emitTimeAndDateToDateBuffer
.LAD7F      BIT prvDateSFTODO1							;b7 of prvDateSFTODO1 controls whether time or date comes first
            BMI dateFirst
            JSR emitTimeToDateBuffer
            JSR emitSeparatorToDateBuffer
            JMP emitDateToDateBuffer
.dateFirst  JSR emitDateToDateBuffer
            JSR emitSeparatorToDateBuffer
            JMP emitTimeToDateBuffer
}

; SFTODO WIP COMMENT
; prvDateSFTODO1:
; b4..7: %1101 => emit just " @ " (i.e. usual b4 set behaviour, but ignoring the other bits) and stop
;        %x1xx => emit just " " and stop
;        %xx1x => emit ","
;        %xx0x => emit "."
;        %xxx0 => stop
;        %xxx1 => emit " " and stop
.emitSeparatorToDateBuffer
{
.LAD96      LDA prvDateSFTODO1
            AND #&F0
            CMP #&D0
            BEQ emitSpaceAtSpace
            STA transientDateSFTODO1
            AND #&40
            BNE emitSpace
.LADA5      LDA transientDateSFTODO1
            LDX #','
            AND #&20
            BNE separatorInX
            LDX #'.'
.separatorInX
            TXA
            JSR emitAToDateBuffer								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
            LDA transientDateSFTODO1
            AND #&10
            BEQ LAD7Erts
.emitSpace      LDA #' '
            JMP emitAToDateBuffer								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
			
.emitSpaceAtSpace      LDA #' '
            JSR emitAToDateBuffer								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
            LDA #'@'
            JSR emitAToDateBuffer								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
            JMP emitSpace
}

; SFTODO: "Ish" in name because I think this will be affected by the bug in calculateDaysBetween1stJanAndPrvDateSFTODOIsh
.calculateDaysBetween1stJan1900AndPrvDateSFTODOIsh
{
; SFTODO: This has only one caller
.LADCB      LDA #0
            STA prvDateSFTODO0
            SEC
            LDA prvDateCentury
            SBC #19
            BCC LAE26 ; SFTODO: branch if error? (branch if prvDateCentury<19, but LAE26 is used below too)
            BEQ centuryAdjustInA
            CMP #1
            BNE LAE26
            LDA #100
.centuryAdjustInA
            CLC
            ADC prvDateYear
	  ; A now contains yearsSince1900=four digit year-1900.
            PHA
            STA prvA
            LDA #lo(daysPerYear)
            STA prvB
            JSR mul8
	  ; We now have prvDC = yearsSince1900*lo(daysPerYear); prvDC+1 might be as high as 84 if yearsSince1900=199
            CLC
            PLA
            PHA
            ADC prvDC + 1
            STA prvDC + 1
	  ; We now have prvDC += yearsSince1900*hi(daysPerYear)*256, since hi(daysPerYear) == 1 SFTODO: note this may overflow, e.g. if yearsSince1900=199 prvDC + 1 "should" be 84+199=283, but we don't check
            PLA
            LSR A
            LSR A
            CLC
            ADC prvDC
            STA prvDC
	  ; SFTODO: Could save a few bytes with BCC:INC trick
            LDA prvDC + 1
            ADC #0
            STA prvDC + 1
	  ; prvDC += yearsSince1900 DIV 4
            BCS LAE26 ; branch if we've overflowed SFTODO: seems a little pointless, we didn't check for overflow above so why only here? Just maybe this works out correctly, but I'm a little dubious.
	  ; We have prvDC = yearsSince1900*daysPerYear + yearsSince1900 DIV 4 = days since January 1st 1900.
            JSR calculateDaysBetween1stJanAndPrvDateSFTODOIsh
            CLC
            LDA prvDateSFTODO4
            ADC prvDC
            STA prvDateSFTODO4
            LDA prvDateSFTODO4 + 1
            ADC prvDC + 1
            STA prvDateSFTODO4 + 1
	  ; We have now (SFTODO: ignoring possible bug in calculateDaysBetween1stJanAndPrvDateSFTODOIsh) calculated the number of days from January 1st 1900 to prvDate.
            BCS LAE26 ; branch if we've overflowed SFTODO: pointless? well, at least inconsistent/incomplete?
            RTS
			
.LAE26      LDA #&FF
            STA prvDateSFTODO0
            RTS
}

; SFTODO: This has only one caller
; SFTODO: I suspect this subroutine is (intended to be) the inverse of JSR calculateDaysBetween1stJan1900AndPrvDateSFTODOIsh - yes, I haven't followed the logic through step by step but it looks very much like it
.convertDaysSince1stJan1900ToDate
{
daysBetween1stJan1900And2000 = 36524 ; frink: #2000/01/01#-#1900/01/01# -> days
.LAE2C      LDA #19
            STA prvDateCentury
            SEC
            LDA prvDateSFTODO4
            SBC #lo(daysBetween1stJan1900And2000)
            STA prvA
            LDA prvDateSFTODO4 + 1
            SBC #hi(daysBetween1stJan1900And2000)
            BCC prvDateCenturyOK
            STA prvDateSFTODO4 + 1
            LDA prvA
            STA prvDateSFTODO4
            INC prvDateCentury
.prvDateCenturyOK
	  ; By this point we've adjusted prvDateSFTODO4 and prvDateCentury so we now SFTODO: GUESSING want to calculate the number of days between prvDate and 1st January (prvCentury 00)
	  LDA #0
            STA prvDateYear
.LAE52      JSR testLeapYear ; set C iff prvDateYear is a leap year
            LDA #lo(daysPerYear)
            ADC #0
            STA prvA
            LDA #hi(daysPerYear)
            STA prvB
            SEC
            LDA prvDateSFTODO4
            SBC prvA
            STA prvA
            LDA prvDateSFTODO4 + 1
            SBC prvB
            BCC LAE82
            STA prvDateSFTODO4 + 1
            LDA prvA
            STA prvDateSFTODO4
            INC prvDateYear
            JMP LAE52
			
.LAE82      LDA #&01
            STA prvDateMonth
.LAE87      LDY prvDateMonth
            JSR getDaysInMonthY
            STA prvA
            SEC
            LDA prvDateSFTODO4
            SBC prvA
            STA prvA
            LDA prvDateSFTODO4 + 1
            SBC #&00
            BCC LAEB0
            STA prvDateSFTODO4 + 1
            LDA prvA
            STA prvDateSFTODO4
            INC prvDateMonth
            JMP LAE87
			
.LAEB0      LDX prvDateSFTODO4
            INX
            STX prvDateDayOfMonth
            JMP calculateDayOfWeekInPrvDateDayOfWeek
}

{
; SFTODO: This is like incrementPrvDateRespectingOpenElements but (presumably) we know the day of month is open and we increment it by a week not the one day incrementPrvDateRespectingOpenElements would do when it's open.
; SFTODO: This has only one caller
.^incrementPrvDateByOneWeek
.LAEBA      CLC
            LDA prvDateDayOfMonth
            ADC #7
            STA prvDateDayOfMonth
            LDY prvDateMonth
            JSR getDaysInMonthY
            CMP prvDateDayOfMonth
            BCS clvClcRts
            STA prvTmp2
            SEC
            LDA prvDateDayOfMonth
            SBC prvTmp2
            STA prvDateDayOfMonth
            JMP LAEF8 ; SFTODO: This is probably "incrementPrvDateMonthBy1"

; SFTODO: I am still figuring this code out, but what I think this is doing is incrementing the date part of PrvDate* - it's not a simple increment by 1, because we do *not* change anything the user has explicitly specified, we only change "open" elements the user didn't specify. Note that we need to continue to respect openness (it's really more that we're respecting *non*-openness) as we cascade the change into more significant parts of the date when the increment moves an element out of range.
; SFTODO: Whether we succeeded or not is indicated by C and V flags - there is probably a common pattern of these across all the date code, once I get a clearer picture
.^incrementPrvDateRespectingOpenElements
.LAEDE      LDA #&02 ; SFTODO: test bit indicating prvDateDayOfMonth is &FF
            BIT prv2Flags
            BEQ prvDayOfMonthNotOpen ; SFTODO: Not quite sure about this - I think this is saying "it wasn't specified by the user", but *we* may have filled it in the meantime - the fact we go and INC it kind of implies we have
            INC prvDateDayOfMonth
            LDY prvDateMonth
            JSR getDaysInMonthY
            CMP prvDateDayOfMonth
            BCS clvClcRts
            LDA #1
            STA prvDateDayOfMonth
.prvDayOfMonthNotOpen
.LAEF8      LDA #&04 ; SFTODO: test bit indicating prvMonth is &FF
            BIT prv2Flags
            BEQ prvMonthNotOpen
            INC prvDateMonth
            LDA prvDateMonth
            CMP #13
            BCC clvClcRts
            LDA #1
            STA prvDateMonth
.prvMonthNotOpen
            LDA #&08 ; SFTODO: test bit indicating prvYear is &FF
            BIT prv2Flags
            BEQ prvYearNotOpen
            INC prvDateYear ; SFTODO: *probably* sets prvDateYear to 0 - but then why would we do the following, so maybe it doesn't?
            LDA prvDateYear
            CMP #100
            BCC sevClcRts
            LDA #0
            STA prvDateYear
.prvYearNotOpen
            LDA #&10 ; SFTODO: test bit indicating prvCentury is &FF
            BIT prv2Flags
            BEQ sevClcRts ; SFTODO: branch if prvCentury not open
            INC prvDateCentury
            LDA prvDateCentury
            CMP #100
            BCC sevClcRts
            LDA #0
            STA prvDateCentury
            SEC
            RTS
			
.^clvClcRts      CLV
            CLC
            RTS
			
.^sevClcRts BIT rts
            CLC
.rts        RTS
}

; SFTODO: Note that unlike incrementPrvDateRespectingOpenElements, this does *not* respect open elements - I suspect this is correct given how it's called (e.g. - making this up - by the time we get to this point we have "picked" a date and we're just moving it back one day at a time to meet some additional criterion) but it *is* a difference worth noting in final comments.
; SFTODO: I think we return with C and V clear if things are OK; we return with C clear and V set if the year gets decremented, or C set (not sure about V, probably clear) if the century gets decremented below 0
.decrementPrvDateBy1
{
.LAF44      DEC prvDateDayOfMonth
            BNE clvClcRts
            LDY prvDateMonth
            DEY
            BNE wrapMonth
            LDY #12
.wrapMonth  JSR getDaysInMonthY
            STA prvDateDayOfMonth
            STY prvDateMonth
            CPY #12
            BCC clvClcRts
            DEC prvDateYear
            LDA prvDateYear
            CMP #&FF
            BNE sevClcRts
            LDA #99
            STA prvDateYear
            DEC prvDateCentury
            LDA prvDateCentury
            CMP #&FF
            BNE sevClcRts
            SEC ; SFTODO: redundant?
            RTS
}

{
; SFTODO: This seems (ignoring for the moment the work done when it does JMP SFTODOProbCalculateDayOfWeekClcRts) to fix up missing parts (&FF) of the date (not time) with the relevant component of 1900/01/01 (ish; I haven't traced the LAFAA branch yet either)
; SFTODO: This has only one caller
.^SFTODOProbDefaultMissingDateBitsAndCalculateDayOfWeek ; SFTODO: I think this is a poor (incomplete) label, because in the yearOpen case we are adjusting the date until we match the fixed parts
.LAF79      LDA prv2Flags
            AND #&08
            BNE yearOpen ; SFTODO: branch if prvDateYear is &FF, i.e. user didn't supply a year
            LDA prv2Flags
            AND #&10
            BEQ haveCentury ; SFTODO: branch if prvDateCentury is not &FF
            LDA #19 ; default century to 19 SFTODO: probably OK, but should we default to whatever the current century is instead, as we do elsewhere??
            STA prvDateCentury
            LDA prv2Flags
            AND #&0F ; clear bit indicating prvDateCentury was &FF
            STA prv2Flags
.haveCentury
	  ; SFTODO: Replace &FF values in prvDate{Century,Year,Month,DayOfMonth} with 0,0,1,1 respectively - so we're sort of defaulting to 1900/01/01, probably, given the defaulting of prvCentury earlier
	  LDX #&00
.loop       LDA prvDateCentury,X
            CMP #&FF
            BNE LAF9F
            TXA
            LSR A
.LAF9F      STA prvDateCentury,X
            INX
            CPX #&04
            BNE loop
            JMP SFTODOProbCalculateDayOfWeekClcRts

; SFTODOWIP
.yearOpen   JSR getRtcDayMonthYear
            LDA prv2Flags
            AND #&1E ; test all bits of prv2Flags except DayOfWeek
            CMP #&1E
            BEQ SFTODOProbCalculateDayOfWeekClcRts ; branch if *all* of century/year/month/day-of-month are open
            LDA prv2Flags
            STA prvTmp6 ; SFTODO: TEMP STASH ORIGINAL prv2Flags?
            LDA #&1E ; SFTODO: temporarily set prv2Flags so all of century/year/month/day-of-month are open
            STA prv2Flags ; SFTODO: We must be doing this for the benefit of incrementPrvDateRespectingOpenElements
.incLoop    LDA prv2DateDayOfMonth
            CMP #&FF
            BEQ dayOfMonthOpen
            CMP prvDateDayOfMonth
            BNE prvDateDoesntMatchFixed
.dayOfMonthOpen
            LDA prv2DateMonth
            CMP #&FF
            BEQ monthOpen
            CMP prvDateMonth
            BEQ prvDateMatchesFixed
.prvDateDoesntMatchFixed
            JSR incrementPrvDateRespectingOpenElements
            BCC incLoop
            LDA prvTmp6 ; SFTODO: RESTORE STASHED prv2Flags FROM ABOVE?
            STA prv2Flags
            SEC
            RTS

.prvDateMatchesFixed
.monthOpen  LDA prvTmp6 ; RESTORE STASHED prv2Flags FROM ABOVE?
            STA prv2Flags
.SFTODOProbCalculateDayOfWeekClcRts
            JSR calculateDayOfWeekInA
            STA prvDateDayOfWeek
            LDA #&00
            STA prvDateSFTODO0
            CLC
            RTS
}

;SFTODOWIP
{
.^LAFF9
	  ; Copy prvDate{Century,Year,Month,DayOfMonth,DayOfWeek} to prv2{...} SFTODO: I suspect we do this because we want to retain the original user partial date specification as we will in the answers in prvDate*, which is where we will print the final answer from
	  LDX #&04
.LAFFB      LDA prvDateCentury,X
            STA prv2DateCentury,X
            DEX
            BPL LAFFB
	  ; Set prv2Flags so b4-0 are set iff prv{Century,Year,Month,DayOfMonth,DayOfWeek} is &FF.
            LDX #&00
            STX prv2Flags
.loop       LDA prvDateCentury,X
            CMP #&FF
            ROL prv2Flags
            INX
            CPX #&05
            BNE loop
            JSR SFTODOProbDefaultMissingDateBitsAndCalculateDayOfWeek ; SFTODO: RETURNS SOMETHING IN C, ALSO PROBABLY IN prvDateSFTODO0 ("OK" EXIT PATH SETS IT TO 0, I THINK)
            BCS badDate3
            LDA prv2DateDayOfWeek
            CMP #&FF
            BNE dayOfWeekNotOpen
            JSR validateDateTimeRespectingLeapYears
            LDA prvDateSFTODO0
            AND #&F0
            BNE badDate3
            CLC
            RTS

.badDate3   BIT rts
            SEC
.rts        RTS

.dayOfWeekNotOpen ; SFTODO: I think this code is adjusting the date we've calculated up until now to satisfy user conditions like "last Tuesday in X" or whatever, but I am guessing - however, I chose this label because we come here if the prv2 *copy* of the user's initial inputs lacks the day of week
            CMP #&07
            BCC LB03E
            CMP #&5B
            BCC LB086 ; SFTODO: maybe one of the "before/after day of week" type queries???
            JMP LB0F3 ; SFTODO: ditto???

; SFTODO: *Maybe* the case where we want a specific day of week!? Pure guesswork
.LB03E      LDA prv2Flags
            AND #&0E ; SFTODO: get bits indicating if prv{Year,Month,DayOfMonth} are &FF
            BNE someOfPrvYearMonthDayOfMonthOpen
            JSR validateDateTimeRespectingLeapYears
            LDA prvDateSFTODO0
            AND #&F0 ; SFTODO: get century, year, month, day of month flags?
            BNE badDate2
.someOfPrvYearMonthDayOfMonthOpen
            INC prv2DateDayOfWeek
.LB052      LDA prv2DateDayOfWeek
            CMP prvDateDayOfWeek
            BEQ LB071
.LB05A      JSR incrementPrvDateRespectingOpenElements
            BCS badDate2
            BVC LB068
            LDA #&08
            BIT prv2Flags
            BEQ LB083
.LB068      JSR calculateDayOfWeekInA
            STA prvDateDayOfWeek
            JMP LB052 ; SFTODO: Looks like we're looping round, and incrementPrvDateRespectingOpenElements at least sometimes increments day of month, so I wonder if this is implementing one of the "search for date where day of week is X" operations - maybe
			
.LB071      JSR validateDateTimeRespectingLeapYears
            LDA prvOswordBlockCopy
            AND #&F0
            BNE LB05A
.LB07B      CLV
            CLC
            RTS

; SFTODO: As elsewhere, do we really need so many copies of this and similar code fragments? (We might, but check.)
.badDate2   SEC
            BIT rts2
.rts2       RTS

.LB083      CLV
            SEC
            RTS
			
.LB086      STA prvA
            LDA #0
            STA prvB
            LDA #7
            STA prvC
            JSR SFTODOPSEUDODIV
            TAX
            INX
            STX prvDateDayOfWeek
            LDA #&1E
            STA prv2Flags
            LDX prvD
            CPX #10
            BEQ LB0E7
            CPX #11
            BEQ LB0CD
            CPX #12
            BEQ LB0DA
            TXA
            PHA
.LB0B1      JSR calculateDayOfWeekInA
            CMP prvDateDayOfWeek
            BEQ LB0C1
            JSR incrementPrvDateRespectingOpenElements
            BCC LB0B1
            PLA
            BCS badDate2
.LB0C1      PLA
            TAX
.LB0C3      DEX
            BEQ LB07B
            JSR incrementPrvDateByOneWeek
            BCC LB0C3
            CLV
            RTS

.LB0CD      JSR incrementPrvDateRespectingOpenElements
            JSR calculateDayOfWeekInA
            CMP prvDateDayOfWeek
            BNE LB0CD
            BEQ LB07B
.LB0DA      JSR decrementPrvDateBy1
            JSR calculateDayOfWeekInA
            CMP prvDateDayOfWeek
            BNE LB0DA
            BEQ LB07B
.LB0E7      JSR calculateDayOfWeekInA
            CMP prvDateDayOfWeek
            BEQ LB07B
            BCS LB0DA
            BCC LB0CD

.LB0F3      LDA #&1E
            STA prv2Flags
            LDA prv2DateDayOfWeek
            CMP #&9B
            BCC LB116
            SBC #&9A
            TAX
.LB102      JSR incrementPrvDateRespectingOpenElements
            BCC LB10A
            JMP badDate2
			
.LB10A      DEX
            BNE LB102
            JSR calculateDayOfWeekInA
            STA prvDateDayOfWeek
            JMP LB07B
			
.LB116      SEC
            SBC #&5A
            TAX
.LB11A      JSR decrementPrvDateBy1
            BCC LB122
            JMP badDate2
			
.LB122      DEX
            BNE LB11A
            JSR calculateDayOfWeekInA
            STA prvDateDayOfWeek
            JMP LB07B

.^badDate	  SEC
            BIT rts3
.rts3       RTS
}

;SFTODOWIP
; This subroutine implements the date calculation features of the *DATE and *CALENDAR commands.
; The calculation to perform is parsed from the command line using (transientCmdPtr),Y.
; On entry, SFTODO!
; On exit, C is clear iff the calculation succeeded. If C is set, V set indicates "Bad date", V clear indicates "Mismatch".
.dateCalculation
{
.LB133
	  ; Set the prvDate* addresses relating to date (as opposed to time) to &FF. SFTODO: PROB TRUE BUT CHECK This is used to indicate that the user has not specified any values for them; we fill these in as we parse the command line and the &FF values left over are the ones we need to calculate.
	  LDX #&04
            LDA #&FF
.setFFLoop  STA prvDateCentury,X
            DEX
            BPL setFFLoop
            JSR findNextCharAfterSpace								;find next character. offset stored in Y
            LDA (transientCmdPtr),Y
            CMP #vduCr
            BEQ dateArgumentParsed
            JSR SFTODOProbParsePlusMinusDate
            BCS badDate
            STA prvDateDayOfWeek
            CMP #&FF
            BEQ dayOfWeekOpen
	  ; The user has specified a day of the week; if there's no trailing comma this is the end of the user-specified partial date.
            JSR findNextCharAfterSpace								;find next character. offset stored in Y
            LDA (transientCmdPtr),Y
            CMP #','
            BNE dateArgumentParsed
            INY
.dayOfWeekOpen
            JSR convertIntegerDefaultDecimal
            BCC dayOfMonthInA
            LDA #&FF
.dayOfMonthInA
            STA prvDateDayOfMonth
	  ; After the day of the month there may be a '/' followed by month/year components; if there's no '/' we have finished parsing the user-specified partial date.
            JSR findNextCharAfterSpace								;find next character. offset stored in Y
            LDA (transientCmdPtr),Y
            CMP #'/'
            BNE dateArgumentParsed
            INY
            JSR convertIntegerDefaultDecimal
            BCC monthInA
            LDA #&FF
.monthInA   STA prvDateMonth
	  ; After the month there may be a '/' followed by a year component; if there's no '/' we have finished parsing the user-specified partial date.
            JSR findNextCharAfterSpace								;find next character. offset stored in Y
            LDA (transientCmdPtr),Y
            CMP #'/'
            BNE dateArgumentParsed
            INY
            JSR convertIntegerDefaultDecimal
            BCC parsedYearOK
            LDA #&FF
            STA prvDateYear
            STA prvDateCentury
            JMP dateArgumentParsed
.parsedYearOK
	  JSR interpretParsedYear
.dateArgumentParsed
  	  ; SFTODO: I am kind of guessing that at this point the command argument has been parsed and anything "provided" has been filled in over the &FF defaults we put in place at the start. So if we're doing a simple "*DATE", *everything* (date-ish, not time-ish) will be &FF.
	  JSR validateDateTimeAssumingLeapYear ; SFTODO: *just possibly* it would be better to validate *respecting* leap year *iff* prvDateYear/prvDateCentury are not &FF (i.e. we have a specific year) - but I could very easily be missing some subtlety here - note that in LAFF9 we redo the validation respecting leap year after filling in the blanks, so this is probably *not* a helpful tweak here - OK, LAFF9 will *sometimes* redo the validation, so just maybe (it's all very unclear right now) this tweak would add a tiny bit of value
	  ; Stash the date validation result (shifted into the low nybble) on the stack.
            LDA prvDateSFTODO0
	  ; SFTODO: Use lsrA4
            LSR A
            LSR A
            LSR A
            LSR A
            PHA
	  ; Set prvDateSFTODO0 so b3-0 are set iff prvDate{Century,Year,Month,DayOfMonth} is &FF.
            LDX #&00
            STX prvDateSFTODO0
.loop       LDA prvDateCentury,X
            CMP #&FF								;set carry iff A=&FF
            ROL prvDateSFTODO0							;rotate carry into prvOswordBlockCopy
            INX
            CPX #&04
            BNE loop
	  ; Invert prvDateSFTODO0 b0-3, so b3-0 are set iff prvDate{Century,Year,Month,DayOfMonth} is not &FF. SFTODO: I THINK I MAY HAVE HAD THE SENSE OF THIS THE WRONG WAY ROUND IN SOME OF MY CODE ANALYSIS
            LDA prvDateSFTODO0
            EOR #&0F
            STA prvDateSFTODO0
	  ; AND prvDateSFTODO0 with the date validation mask we stacked earlier; this will ignore validation errors
	  ; where the corresponding prvDate* address was &FF.
            PLA
            AND prvDateSFTODO0
            AND #&0F ; SFTODO: redundant? the value we just pulled with PLA had undergone 4xLSR A so high nybble was already 0
            BNE badDateIndirect ; branch if still some validation errors after masking off open (&FF) values
            JMP LAFF9

.badDateIndirect
            JMP badDate
}

; Take the parsed 2-byte integer year at L00B0 and populate prvDate{Year,Century}, defaulting the century to the current century if a two digit year is specified.
.interpretParsedYear
{
.LB1CA      LDA L00B0 ; SFTODO: low byte of parsed year from command line
            STA prvA
            LDA L00B1 ; SFTODO: high byte of parsed year from command line
            STA prvB
            LDA #100
            STA prvC
            JSR SFTODOPSEUDODIV
            STA prvDateYear
            LDA prvD
            BNE centuryInA
.^defaultPrvDateCentury
            LDX #userRegCentury
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
.centuryInA STA prvDateCentury
            RTS
}

; SFTODO: This seems to be parsing the "+"/"-" support for *DATE/*CALENDAR and returning with the offset in some form in A (&FF meaning not present/couldn't parse or something like that), probably returns with C clear iff parsed OK. - I think as a whole it's parsing +/- a number of days, a specific day of the week or the +/-day-of-week stuff - this is *probably* why A seems to get shifted round, as I think all this different functionality is mapped into A on return, but not sure
; SFTODO: This has only one caller
.SFTODOProbParsePlusMinusDate
{
.LB1ED      STY prvTmp2
            LDA #&00
            STA transientDateSFTODO1
            JSR findNextCharAfterSpace								;find next character. offset stored in Y
            LDA (transientCmdPtr),Y
            CMP #'+'
            BEQ plus
            CMP #'-'
            BNE notMinus
	  ; SFTODO: Similar chunk of code here and at .plus, could we factor out?
            INY
            JSR convertIntegerDefaultDecimal
            BCS LB20B ; SFTODO: Branch if parsing failed
            CMP #&00
            BNE LB20D
.LB20B      LDA #&01
.LB20D      CMP #63+2 ; SFTODO: user guide says 63 is max value, not sure why +2 instead of +1 (+1 make sense as we bcs == branch-if-greater-or-equal)
            BCS LB229
            ADC #&5A ; SFTODO!?
            CLC
            RTS
			
.plus       INY
            JSR convertIntegerDefaultDecimal
            BCS LB21F ; SFTODO: Branch if parsing failed
            CMP #&00
            BNE LB221
.LB21F      LDA #&01
.LB221      CMP #99+2 ; SFTODO: user gide says 99 is max value, as above not sure why +2 instead of +1
            BCS LB229
            ADC #&9A ; SFTODO!?
            CLC
            RTS

; SFTODO: THIS LABEL IS PROBABLY "PARSING FOR THIS FRAGMENT FAILED"
.LB229      LDA #&FF
            SEC
            RTS

; SFTODO: It looks like this is parsing a day name from the command line, returning with A populated and C clear if parsed OK, otherwise returning with A=&FF and C set.
.notMinus   LDX #&00 ; SFTODO: Rename label "notPlusMinus"?
.LB22F      STX prvTmp4
            LDA calOffsetTable+1,X
            STA transientDateSFTODO2
            LDA calOffsetTable,X
            STA prvTmp3
            TAX
.LB23E      LDA (transientCmdPtr),Y
            ORA #&20								;force lower case (imperfectly)
            CMP calText,X
            BNE LB24F
            INY
            INX
            CPX transientDateSFTODO2
            BEQ LB26A
            BNE LB23E
.LB24F      SEC
            TXA
            SBC prvTmp3
            CMP #&02
            BCS LB26A
            LDY prvTmp2
            LDX prvTmp4
            INX
            CPX #&08
            BCC LB22F
            LDY prvTmp2
            LDA #&FF
            CLC
            RTS

; SFTODO: This bit looks like it's probably checking for +/- *after* a day name (e.g. "*DATE TU+,23/10/19")
.LB26A      LDA prvTmp4
            BNE LB27B
            LDX #&06								;Select 'Day of Week' register on RTC: Register &06
            JSR ReadRtcRam								;Read data from RTC memory location X into A
            STA prvTmp4
            LDA #&FF
            STA transientDateSFTODO1
.LB27B      LDX #&00
            LDA (transientCmdPtr),Y
            CMP #'+'
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
.LB2A1      DEC prvTmp4
            STX prvTmp5
            TXA
            ASL A
            ASL A
            ASL A
            SEC
            SBC prvTmp5
            CLC
            ADC prvTmp4
            CLC
            RTS
}

; Parse a time from the command line, populating prvDate* and returning with C clear iff parsing succeeded.
.parseAndValidateTime
{
.LB2B5      JSR convertIntegerDefaultDecimal
            BCS parseError
            STA prvDateHours
            LDA (transientCmdPtr),Y
            INY
            CMP #':'
            BNE parseError
            JSR convertIntegerDefaultDecimal
            BCS parseError
            STA prvDateMinutes
            LDA (transientCmdPtr),Y
            CMP #':'
            BEQ skipCharAndParseSeconds
            CMP #'/'
            BEQ skipCharAndParseSeconds
            LDA #0 ; default to 0 seconds if not specified
            BEQ secondsInA ; always branch
.skipCharAndParseSeconds
            INY
            JSR convertIntegerDefaultDecimal
            BCS parseError
.secondsInA STA prvDateSeconds
            TYA
            PHA
            JSR validateDateTimeAssumingLeapYear
            PLA
            TAY
            LDA prvOswordBlockCopy
            AND #&07								;did hour/minutes/second part fail validation?
            BNE parseError								;branch if fail
            CLC
            RTS
			
.parseError SEC
            RTS
}

{
; SFTODO: This has only one caller
.^LB2F5      LDA #&00
            STA prvDateDayOfWeek
            JSR convertIntegerDefaultDecimal
            BCS LB32F
            STA prvDateDayOfMonth
            LDA (transientCmdPtr),Y
            INY
            CMP #'/'
            BNE LB32F
            JSR convertIntegerDefaultDecimal
            BCS LB32F
            STA prvDateMonth
            LDA (transientCmdPtr),Y
            INY
            CMP #'/'
            BNE LB32F
            JSR convertIntegerDefaultDecimal
            BCS LB32F
            JSR interpretParsedYear
            JSR validateDateTimeAssumingLeapYear
            LDA prvDateSFTODO0
            AND #&F0
            BNE LB32F
            JSR calculateDayOfWeekInPrvDateDayOfWeek
            CLC
            RTS
			
.LB32F      SEC
            RTS
}
			
.LB331      CLV
            CLC
            JMP (KEYVL)

; SFTODO: Mostly un-decoded
{
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

.^LB34E      LDX #userRegAlarm
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

.^LB35E      SEC
.^LB35F      LDA romselCopy
            PHA
            LDA ramselCopy
            PHA
            AND #ramselShen
            ORA #ramselPrvs1
            STA ramselCopy
            STA ramsel
            LDA romselCopy
            ORA #romselPrvEn
            STA romselCopy
            STA romsel
            BCC LB3CA

	  LDX #userRegAlarm
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
            JSR ReadRtcRam								;Read data from RTC memory location X into A
            AND #&F0
            ORA #&0E
            JSR WriteRtcRam								;Write data from A to RTC memory location X
            LDX #&0B								;Select 'Register B' register on RTC: Register &0B
            JSR ReadRtcRam								;Read data from RTC memory location X into A
            ORA #&40								;Enable Periodic Interrupts
            JSR WriteRtcRam								;Write data from A to RTC memory location X
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
	  ; SFTODO: I am not sure this is necessary, can't we do OSWORD 7 with a parameter block in SWR?
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
            LDX #userRegAlarm
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            LSR A
            AND #&20
            STA prv82+&76
            LDX #&0B								;Select 'Register B' register on RTC: Register &0B
            JSR ReadRtcRam								;Read data from RTC memory location X into A
            AND #&9F
            ORA prv82+&76
            JSR WriteRtcRam								;Write data from A to RTC memory location X
            LDX #&0A								;Select 'Register A' register on RTC: Register &0A
            JSR ReadRtcRam								;Read data from RTC memory location X into A
            AND #&F0
            JSR WriteRtcRam								;Write data from A to RTC memory location X
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
}

; On entry, X=rtcRegC and A is the value read from rtcRegC.
.RtcInterruptHandler
{
    DEX:ASSERT rtcRegC - 1 == rtcRegB
    JSR Nop3:STX rtcAddress
    JSR Nop3:AND rtcData
    ; We now have A = (RTC register B) AND (RTC register C); this means we have bits set in A
    ; for interrupts which have triggered and are not masked off. We shift A left and test the
    ; bits as they fall off into the carry.
    ; SFTODO: As far as I can see, SeiSelectRtcAddressXVariant will disable interrupts and
    ; nothing will re-enable them. Am I missing something? Is this correct behaviour?
    JSR SeiSelectRtcAddressXVariant
    ASL A:ASL A:BCC NoPeriodicInterrupt
    PHA
    CLC:JSR LB35F
    PLA
.NoPeriodicInterrupt
    ASL A:BCC NoAlarmInterrupt
    PHA
    JSR LB34E
    PLA
.NoAlarmInterrupt
    ASL A:BCC NoUpdateEndedInterrupt
    ; DELETE: Is the support for notifying user code of update ended interrupts really useful?
    ; Access to the RTC via OSBYTE calls will automatically wait for updates to pass, and any
    ; code dealing directly with the RTC chip could just wait for updates to pass itself.
    LDX #prvRtcUpdateEndedOptions - prv83:JSR readPrivateRam8300X
    PHA
    AND #prvRtcUpdateEndedOptionsGenerateUserEvent
    BEQ DontGenerateUserEvent
    LDY #eventNumUser:JSR OSEVEN
.DontGenerateUserEvent
    PLA
    AND #prvRtcUpdateEndedOptionsGenerateServiceCall
    BEQ DontGenerateServiceCall
    LDX #serviceUpdateEnded:JSR osEntryOsbyteIssueServiceRequest
.DontGenerateServiceCall
.NoUpdateEndedInterrupt
    JMP ExitAndClaimServiceCall
}

.PrvDisMismatch
      	  JSR PrvDis								;switch out private RAM
            JSR raiseError								;Goto error handling, where calling address is pulled from stack

            EQUB &80
  	  EQUS "Mismatch", &00

.PrvDisBadDate
	  JSR PrvDis								;switch out private RAM
            JSR raiseError								;Goto error handling, where calling address is pulled from stack

            EQUB &80
	  EQUS "Bad date", &00

.PrvDisBadTime
	  JSR PrvDis								;switch out private RAM
            JSR raiseError								;Goto error handling, where calling address is pulled from stack

            EQUB &80
	  EQUS "Bad time", &00

;*TIME Command
{
.^time      JSR PrvEn								;switch in private RAM
            LDA (transientCmdPtr),Y							;read first character of command parameter
            CMP #'='								;check for '='
            BEQ setTime								;if '=' then set time, else read time
            JSR initDateSFTODOS							;store #&05, #&84, #&44 and #&EB to addresses &8220..&8223
            LDA #&FF
            STA prvDateSFTODO7							;store #&FF to address &8227
            STA prvDateSFTODO6							;store #&FF to address &8226
            LDA #lo(prvDateBuffer)
            STA prvDateSFTODO4							;store #&00 to address &8224
            LDA #hi(prvDateBuffer)
            STA prvDateSFTODO4 + 1							;store #&80 to address &8225
            JSR getRtcDateTime							;read TIME & DATE information from RTC and store in Private RAM (&82xx)
            JSR initDateBufferAndEmitTimeAndDate								;format text for output to screen?
            JSR printDateBuffer								;output TIME & DATE data from address &8000 to screen
.PrvDisExitAndClaimServiceCall
            JSR PrvDis								;switch out private RAM
            JMP ExitAndClaimServiceCall								;Exit Service Call								;
			
.setTime    INY
            JSR parseAndValidateTime
            BCC parseOk
            JMP PrvDisBadTime								;Error with Bad time
.parseOk    JSR WriteRtcTime								;Read 'Seconds', 'Minutes' & 'Hours' from Private RAM (&82xx) and write to RTC
            JMP PrvDisExitAndClaimServiceCall								;switch out private RAM and exit
}

;*DATE Command
{
.^date	  JSR PrvEn								;switch in private RAM
            LDA (transientCmdPtr),Y							;read first character of command parameter
            CMP #'='								;check for '='
            BEQ setDate								;if '=' then set date, else read date
            JSR initDateSFTODOS								;store #&05, #&84, #&44 and #&EB to addresses &8220..&8223
            LDA prvDateSFTODO2 ; SFTODO: It would be shorter just to do LDA #xx:STA prvDateSFTODO2
            AND #&F0
            STA prvDateSFTODO2							;store #&40 to address &8222, updating value set by initDateSFTODOS
            JSR dateCalculation
            BCC calculationOk
            BVS PrvDisBadDateIndirect
            JMP PrvDisMismatch								;Error with Mismatch

.PrvDisBadDateIndirect
            JMP PrvDisBadDate								;Error with Bad Date

.calculationOk
            LDA #lo(prvDateBuffer)
            STA prvDateSFTODO4							;store #&00 to address &8224
            LDA #hi(prvDateBuffer)
            STA prvDateSFTODO4 + 1							;store #&80 to address &8225
            JSR initDateBufferAndEmitTimeAndDate								;format text for output to screen?
            JSR printDateBuffer								;output DATE data from address &8000 to screen
.PrvDisexitSc
            JSR PrvDis								;switch out private RAM
            JMP ExitAndClaimServiceCall								;Exit Service Call								;
			
.setDate    INY
            JSR LB2F5
            BCC LB55B
            JMP PrvDisBadDate								;Error with Bad date
			
.LB55B      JSR writeRtcDate								;Read 'Day of Week', 'Date of Month', 'Month' & 'Year' from Private RAM (&82xx) and write to RTC
            JMP PrvDisexitSc								;switch out private RAM and exit
}
			
;Start of CALENDAR * Command
{
dayOfWeek = prvA ; this is also the row number
cellIndex = prvB ; current element in the 42-element structure generated by generateInternalCalendar
column = prvC

.^calend    JSR PrvEn								;switch in private RAM
	  ; SFTODO: Can we share the next few lines of code with *DATE?
            JSR dateCalculation
            BCC calculationOk
            BVS PrvDisBadDateIndirect
            JMP PrvDisMismatch

.PrvDisBadDateIndirect
            JMP PrvDisBadDate

.calculationOk
	  ; Output the month name and year centred (with respect to the calendar width as a whole, not the string).
            LDA #lo(prvDateBuffer2)
            STA prvDateSFTODO4
            LDA #hi(prvDateBuffer2)
            STA prvDateSFTODO4 + 1
            LDA #&05
            STA prvDateSFTODO0
            LDA #&40 ; SFTODO: use just a single space as separator between (empty) time and the date?
            STA prvDateSFTODO1
            LDA #&00 ; SFTODO: don't emit time?
            STA prvDateSFTODO2
            LDA #&F8 ; SFTODO: just emit month name (capitalised) and 4-digit year?
            STA prvDateSFTODO3
            JSR initDateBufferAndEmitTimeAndDate
            SEC
            LDA #23
            SBC transientDateBufferIndex
            LSR A ; divide by two to get the number of spaces on left hand side
            TAX
            LDA #' '
.spaceLoop  JSR OSWRCH
            DEX
            BNE spaceLoop
            LDX #&00
.monthNamePrintLoop
            LDA prvDateBuffer2,X
            JSR OSASCI
            CMP #vduCr
            BEQ monthNamePrinted
            INX
            BNE monthNamePrintLoop
.monthNamePrinted
            JSR generateInternalCalendar
            LDA #1
            STA dayOfWeek
            LDA #0
            STA cellIndex
.rowLoop    LDY #&00
            STY transientDateBufferIndex
            LDA #lo(prvDateBuffer)
            STA transientDateBufferPtr
            LDA #hi(prvDateBuffer)
            STA transientDateBufferPtr + 1
            LDA dayOfWeek
            LDX #3 ; truncate day names to 3 characters
            LDY #&FF ; SFTODO: Comments on emitDayOrMonthName suggest this means *don't* capitalise day names, but we *do* capitalise them (just try *CALENDAR and see)
            CLC
            JSR emitDayOrMonthName
            LDA #&00
            STA column
.columnLoop LDA #' '
            JSR emitAToDateBuffer								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
            LDX cellIndex
            LDA prvDateBuffer2,X
            LDX #3 ; SFTODO: named constants for these values? Anyway, this is right-aligned in a two character field with no leading zeroes and 0 shown as blank
            JSR emitADecimalFormatted								;convert to characters, store in buffer XY?Y, increase buffer pointer, save buffer pointer and return
            INC cellIndex
            INC column
            LDA column
            CMP #6 ; SFTODO: prob use one of named constants I plan to introduce in generateInternalCalendar
            BCC columnLoop
            LDA #vduCr
            JSR emitAToDateBuffer								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
            LDX #&00
.printLoop  LDA prvDateBuffer,X
            JSR OSASCI
            CMP #vduCr
            BEQ printDone
            INX
            BNE printLoop
.printDone  INC dayOfWeek
            LDA dayOfWeek
            CMP #daysPerWeek + 1
            BCC rowLoop
            JSR PrvDis								;switch out private RAM
            JMP ExitAndClaimServiceCall								;Exit Service Call
}

{
.setAlarm   INY
.LB61B      PHP
            JSR parseAndValidateTime
            BCC LB62D
            PLP
            BCC LB62A
            JSR PrvDis								;switch out private RAM
            JMP GenerateSyntaxError
			
.LB62A      JMP PrvDisBadTime

.LB62D      PLP
            JSR copyPrvAlarmToRtc
            JSR findNextCharAfterSpace								;find next character. offset stored in Y
            LDA (transientCmdPtr),Y
            AND #&DF                                                                                ; convert to upper case (imperfectly)
            CMP #'R'
            PHP
            PLA
            LSR A
            LSR A
            PHP
            LDX #userRegAlarm
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            ASL A
            PLP
            ROR A
            JMP LB67C
			
;*ALARM Command
.^alarm     JSR PrvEn								;switch in private RAM
            LDA (transientCmdPtr),Y
            CMP #'='
            CLC
            BEQ setAlarm
            CMP #'?'
            BEQ showAlarm
            CMP #vduCr
            BEQ showAlarm
            JSR parseOnOff
            BCS LB61B
            PHP
            LDX #userRegAlarm
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            PLP
            BNE LB67C
            AND #&BF
            JSR writeUserReg								;Write to RTC clock User area. X=Addr, A=Data
            LDX #rtcRegB								;Select 'Register B' register on RTC: Register &0B
            JSR ReadRtcRam								;Read data from RTC memory location X into A
            AND_NOT rtcRegBPIE OR rtcRegBAIE
            JSR WriteRtcRam								;Write data from A to RTC memory location X
            JMP LB6E3
			
.LB67C      ORA #&40
            JSR writeUserReg								;Write to RTC clock User area. X=Addr, A=Data
            LDX #rtcRegB								;Select 'Register B' register on RTC: Register &0B
            JSR ReadRtcRam								;Read data from RTC memory location X into A
            AND_NOT rtcRegBPIE OR rtcRegBAIE
            ORA #rtcRegBAIE
            JSR WriteRtcRam								;Write data from A to RTC memory location X
            JMP LB6E3
			
.showAlarm  LDA #&40
            STA prvDateSFTODO1
            LDA #&04
            STA prvDateSFTODO2
            LDA #&00
            STA prvDateSFTODO3
            LDA #&FF
            STA prvDateSFTODO7
            STA prvDateSFTODO6
            LDA #lo(prvDateBuffer)
            STA prvDateSFTODO4
            LDA #hi(prvDateBuffer)
            STA prvDateSFTODO4 + 1
            JSR copyRtcAlarmToPrv
            JSR initDateBufferAndEmitTimeAndDate
            DEC prvDateSFTODO1
            JSR printDateBuffer
            LDA #'/'
            JSR OSWRCH								;write to screen
            JSR printSpace								;write ' ' to screen
            LDX #rtcRegB								;Select 'Register B' register on RTC: Register &0B
            JSR ReadRtcRam								;Read data from RTC memory location X into A
            AND #rtcRegBAIE
            JSR printOnOff
            LDX #userRegAlarm
            JSR readUserReg								;Read from RTC clock User area. X=Addr, A=Data
            AND #&80
            BEQ LB6E0
            JSR printSpace								;write ' ' to screen
            LDA #'R'
            JSR OSWRCH								;write to screen
.LB6E0      JSR OSNEWL								;new line
.LB6E3      JSR PrvDis								;switch out private RAM
            JMP ExitAndClaimServiceCall								;Exit Service Call
}
			
;OSWORD &0E (14) Read real time clock
{
.^osword0e	JSR stackTransientCmdSpace						;save 8 bytes of data from &A8 onto the stack
            JSR PrvEn								;switch in private RAM
            LDA oswdbtX								;get X register value of most recent OSWORD call
            STA prvOswordBlockOrigAddr							;and save to &8230
            LDA oswdbtY								;get Y register value of most recent OSWORD call
            STA prvOswordBlockOrigAddr + 1							;and save to &8231
            JSR oswordsv								;save XY entry table
            JSR oswd0e_1								;execute OSWORD &0E
            BCS osword0ea								;successful so don't restore XY entry table
            JSR oswordrs								;restore XY entry table
.osword0ea	LDA prvOswordBlockOrigAddr						;get X register value of most recent OSWORD call
            STA oswdbtX								;and restore to &F0
            LDA prvOswordBlockOrigAddr + 1						;get Y register value of most recent OSWORD call
            STA oswdbtY								;and restore to &F1
            LDA #&0E								;load A register value of most recent OSWORD call (&0E)
            STA oswdbtA								;and restore to &EF
            JSR PrvDis								;switch out private RAM

            JMP unstackTransientCmdSpaceAndExitSC						;restore 8 bytes of data to &A8 from the stack and exit
}
			
;OSWORD &49 (73) - Integra-B calls
{
.^osword49	JSR stackTransientCmdSpace						;save 8 bytes of data from &A8 onto the stack
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

.^unstackTransientCmdSpaceAndExitSC
	  JSR unstackTransientCmdSpace						;restore 8 bytes of data to &A8 from the stack
            JMP ExitAndClaimServiceCall								;Exit Service Call
}
			
;Save OSWORD XY entry table
{
.^oswordsv	LDA prvOswordBlockOrigAddr
            STA L00AE
            LDA prvOswordBlockOrigAddr + 1
            STA L00AF
            LDY #&0F
.oswordsva	LDA (L00AE),Y
            STA prvOswordBlockCopy,Y
            DEY
            BPL oswordsva
            RTS
}
			
;Restore OSWORD XY entry table
{
.^oswordrs	LDA prvOswordBlockOrigAddr
            STA L00AE
            LDA prvOswordBlockOrigAddr + 1
            STA L00AF
            LDY #&0F
.oswordrsa	LDA prvOswordBlockCopy,Y
            STA (L00AE),Y
			DEY
            BPL oswordrsa
            RTS
}
			
;Clear RTC buffer
{
.^LB774      LDY #&0F
            LDA #&00
.LB778      STA prvOswordBlockCopy,Y
            DEY
            BPL LB778
            RTS
}
			
;OSWORD &0E (14) Read real time clock XY?0 parameter lookup code
{
.^oswd0e_1   LDA prvOswordBlockCopy							;get XY?0 value
            ASL A									;x2 (each entry in lookup table is 2 bytes)
            TAY
            LDA oswd0elu+1,Y						;get low byte
            PHA										;and push
            LDA oswd0elu,Y							;get high byte
            PHA										;and push
            RTS										;jump to parameter lookup address

;OSWORD &0E (14) Read real time clock XY?0 parameter lookup table
.oswd0elu	  EQUW oswd0eReadString-1							;XY?0=0: Read time and date in string format
	  EQUW oswd0eReadBCD-1							;XY?0=1: Read time and date in binary coded decimal (BCD) format
	  EQUW oswd0eConvertBCD-1							;XY?0=2: Convert BCD values into string format
}

;OSWORD &49 (73) - Integra-B calls XY?0 parameter lookup code
{
.^oswd49_1	SEC
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
}

; SFTODO: Mostly un-decoded
{
.^LB7BC	  BIT prvOswordBlockCopy + 7
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
}

{
;OSWORD &0E (14) Read real time clock
;XY&0=0: Read time and date in string format
.^oswd0eReadString
.LB81E      JSR getRtcDateTime								;read TIME & DATE information from RTC and store in Private RAM (&82xx)
.^LB821      JSR initDateSFTODOS								;store #&05, #&84, #&44 and #&EB to addresses &8220..&8223
            LDA prvOswordBlockOrigAddr							;get OSWORD X register (lookup table LSB)
            STA prvOswordBlockCopy + 4							;save OSWORD X register (lookup table LSB)
            LDA prvOswordBlockOrigAddr + 1						;get OSWORD Y register (lookup table MSB)
            STA prvOswordBlockCopy + 5							;save OSWORD Y register (lookup table MSB)
            JSR initDateBufferAndEmitTimeAndDate
            SEC
            RTS
}

{
;OSWORD &0E (14) Read real time clock
;XY&0=1: Read time and date in binary coded decimal (BCD) format
.^oswd0eReadBCD
.LB835      JSR getRtcDateTime								;read TIME & DATE information from RTC and store in Private RAM (&82xx)
            LDY #&06
.LB83A      JSR LB85A
            STA (oswdbtX),Y
            DEY
            BPL LB83A
            SEC
            RTS
}

{
;OSWORD &0E (14) Read real time clock
;XY&0=2: Convert BCD values into string format
.^oswd0eConvertBCD
.LB844      LDX #&06
.LB846      LDA prvOswordBlockCopy + 1,X
            JSR LB87A
            STA prvOswordBlockCopy + 9,X
            DEX
            BPL LB846
            LDA #&13
            STA prvOswordBlockCopy + 8
            JMP LB821

.^LB85A      LDA prvOswordBlockCopy + 9,Y
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

; SFTODO: This has only one caller
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
}

;XY?0=&61
;OSWORD &49 (73) - Integra-B calls
.LB891      JSR LB774								;Clear RTC buffer @ &8220-&822F
            JSR getRtcDateTime								;read TIME & DATE information from RTC and store in Private RAM (&82xx)
            CLC
            RTS
			
;XY?0=&60
;OSWORD &49 (73) - Integra-B calls
.LB899		JSR getRtcDateTime								;read TIME & DATE information from RTC and store in Private RAM (&82xx)

;XY?0=&62
;OSWORD &49 (73) - Integra-B calls
.LB89C      LDA #lo(prvDateBuffer)
	  STA prvDateSFTODO4
            LDA #hi(prvDateBuffer)
            STA prvDateSFTODO4 + 1
            JSR initDateBufferAndEmitTimeAndDate
            JMP LB7BC
			
;XY?0=&68
;OSWORD &49 (73) - Integra-B calls
.LB8AC		JSR LAFF9
            CLC
            RTS
			
;XY?0=&69
;OSWORD &49 (73) - Integra-B calls
.LB8B1	  LDA #lo(prvDateBuffer)
            STA prvOswordBlockCopy + 4
            LDA #hi(prvDateBuffer)
            STA prvOswordBlockCopy + 5
            JSR generateInternalCalendar
            LDA #&2A
            STA prvOswordBlockCopy + 1
            JMP LB7BC
			
;XY?0=&64
;OSWORD &49 (73) - Integra-B calls
.LB8C6		JSR LB774
            JSR copyRtcAlarmToPrv
            LDX #&0B								;Select 'Register B' register on RTC: Register &0B
            JSR ReadRtcRam								;Read data from RTC memory location X into A
            AND #&60
            STA prvOswordBlockCopy + 1
            CLC
            RTS

; SFTODO: Don't these next two calls contain most of the logic we'd need to implement OSWORD &F?
;XY?0=&65
;OSWORD &49 (73) - Integra-B calls
.LB8D8	  JSR WriteRtcTime								;Read 'Seconds', 'Minutes' & 'Hours' from Private RAM (&82xx) and write to RTC
            SEC
            RTS
			
;XY?0=&66
;OSWORD &49 (73) - Integra-B calls
.LB8DD	  JSR writeRtcDate								;Read 'Day of Week', 'Date of Month', 'Month' & 'Year' from Private RAM (&82xx) and write to RTC
            SEC
            RTS
			
;XY?0=&67
;OSWORD &49 (73) - Integra-B calls
.LB8E2	  JSR copyPrvAlarmToRtc
            LDA prvOswordBlockCopy + 1
            AND #rtcRegBPIE OR rtcRegBAIE
            STA prvOswordBlockCopy + 1
            LDX #rtcRegB								;Select 'Register B' register on RTC: Register &0B
            JSR ReadRtcRam								;Read data from RTC memory location X into A
            AND_NOT rtcRegBPIE OR rtcRegBAIE
            ORA prvOswordBlockCopy + 1
            JSR WriteRtcRam								;Write data from A to RTC memory location X
            SEC
            RTS

; SFTODO: Perhaps be interesting to write a little test program for the following two calls; we could pre-compute some correct answers and check those (which I suspect would reveal bugs, as per SFTODOs elsewhere), and we could also loop over all dates from 1900/01/01 and round-trip via both of these calls to check that we get the same answer back for each date (and in fact we could also check that the day number was one larger each time - that would in fact remove any need to pre-compute some correct answers)
;XY?0=&6A
;OSWORD &49 (73) - Integra-B calls
.LB8FC	  JSR calculateDaysBetween1stJan1900AndPrvDateSFTODOIsh
            CLC
            RTS
			
;XY?0=&6B
;OSWORD &49 (73) - Integra-B calls
.LB901	  JSR convertDaysSince1stJan1900ToDate
            CLC
            RTS

{
.ExitServiceCallIndirect
    JMP ExitServiceCall

;Error (BRK) occurred - Service call &06
; SFTODO: I really don't know what's going on here. We seem to be checking for an error at
; &FFB4, but that's in the OS ROM in the middle of an instruction. We also do some weird
; stack-swizzling between checking the low and high bytes. My best guess is that this is trying
; to work around a bug (or at least incompatibility) in some other ROM, perhaps one which
; unintentionally triggers a BRK at &FFB4 (it's worth noting &FFB3 is 0=BRK). Maybe something
; to do with shadow RAM given the "workaround" seems to set romselMemsel. Perhaps the
; bug/incompatibility we're trying to workaround is in some application, not a ROM. Might be
; worth asking on stardot about this.
.^service06
    LDA osErrorPtr + 1
    CMP #&FF ; SFTODO: magic number?
    BNE ExitServiceCallIndirect
    LDX osBrkStackPointer
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
    LDA romActiveLastBrk
    STA L0102,X
    LDA osErrorPtr
    CMP #&B4 ; SFTODO: MAGIC NUMBER!?
    BEQ LB936
.LB931
    PLA
    TAX
    PLA
    PLP
    RTS
			
.LB936
    LDA romselCopy
    ORA #romselMemsel
    STA romselCopy
    STA romsel
    TSX
    LDA L0102,X
    STA (vduGraphicsCharacterCell),Y ; SFTODO!?
    JMP LB931
}

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
            AND #maxBank
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
parentWORDV = parentVectorTbl1 + 2
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
		EQUW WrchvHandler-1
		EQUB &0E
		EQUW rdchvHandler-1
		EQUB &10
		EQUW InsvHandler-1
		EQUB &2A
		EQUW RemvHandler-1
		EQUB &2C
		EQUW CnpvHandler-1
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
            ;   &10A,S  xxx (caller's data; nothing to do with us)
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

; Clean up and return from a vector handler; we have dealt with the call and we're not going to
; call the parent handler. At this point the stack should be exactly as described in the big
; comment in vectorEntry; note that this code is reached via JMP so there's no extra return
; address on the stack as there is in restoreOrigVectorRegs.
.returnFromVectorHandler
{
; SQUASH: This is really just shuffling the stack down to remove the return address from "JSR
; ramCodeStubCallIBOS"; can we rewrite it more compactly using a loop?
.LB9E9      TSX
            LDA L0107,X:STA L0109,X
            LDA L0106,X:STA L0108,X
            LDA L0105,X:STA L0107,X
            LDA L0104,X:STA L0106,X
            LDA L0103,X:STA L0105,X
            LDA L0102,X:STA L0104,X
            LDA L0101,X:STA L0103,X
            PLA:PLA
            ; At this point the stack looks like this:
            ;   &101,S  Y stacked by vectorEntry
            ;   &102,S  X stacked by vectorEntry
            ;   &103,S  return address from "JSR vectorEntry" (low)
            ;   &104,S  return address from "JSR vectorEntry" (high)
            ;   &105,S  previously paged in ROM bank stacked by romCodeStubCallIBOS
            ;   &106,S  flags stacked by romCodeStubCallIBOS
            ;   &107,S  A stacked by romCodeStubCallIBOS
            ;   &108,S  xxx (caller's data; nothing to do with us)
            ; We now restore Y and X and RTS from "JSR vectorEntry" in ramCodeStub,
            ; which will restore the previously paged in ROM, the flags and then A,
            ; so the vector's caller will see the Z/N flags reflecting A, but
            ; otherwise preserved.
            PLA:TAY
            PLA:TAX
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
            JMP returnFromBYTEV
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
            BEQ returnFromBYTEV								;jump to code for OSMODE 2-5
.LBA56      LDX #&00
            LDA #&81
            JMP returnViaParentBYTEV								;jump to code for OSMODE 0-1

;OSMODE lookup table
.LBA5D	  EQUB &01								;OSMODE 0 - Not Used
	  EQUB &01								;OSMODE 1 - Not Used
	  EQUB &FB								;OSMODE 2
	  EQUB &FD								;OSMODE 3
	  EQUB &FB								;OSMODE 4
	  EQUB &F5								;OSMODE 5
	  EQUB &01								;OSMODE 6 - No such mode
	  EQUB &01								;OSMODE 7 - No such mode
}

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
            JMP returnViaParentBYTEV
}

; Examine buffer status (http://beebwiki.mdfs.net/OSBYTE_%2698)
.osbyte98Handler
{
.LBA96      JSR jmpParentBYTEV
            BCS returnFromBYTEV
            LDA ramselCopy
            PHA
            ORA #ramselPrvs1
            STA ramselCopy
            STA ramsel
            LDA romselCopy
            PHA
            ORA #romselPrvEn
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
            BCC returnFromBYTEV
            CLC
            LDA (L00FA),Y
            TAY
            LDA #&98
.^returnFromBYTEV
.LBACB      JSR updateOrigVectorRegs
            JMP returnFromVectorHandler
}

{
; Read top of user memory (http://beebwiki.mdfs.net/OSBYTE_%2684)
.^osbyte84Handler
.LBAD1      PHA
            LDA vduStatus
            AND #vduStatusShadow
            BNE shadowMode
            PLA
            JMP returnViaParentBYTEV

; Read base of display RAM for a given mode (http://beebwiki.mdfs.net/OSBYTE_%2685)
.^osbyte85Handler
.LBADC      PHA
            TXA:BMI shadowMode
            LDA osShadowRamFlag:BEQ shadowMode
            PLA
            JMP returnViaParentBYTEV

.shadowMode
            PLA
            LDX #&00
            LDY #&80
            JMP returnFromBYTEV
}

; Enter language ROM (http://beebwiki.mdfs.net/OSBYTE_%268E)
.osbyte8EHandler
{
.LBAF1      LDA #osbyteIssueServiceRequest
            LDX #serviceAboutToEnterLanguage
            LDY #&00
            JSR OSBYTE
            JSR restoreOrigVectorRegs
            JMP returnViaParentBYTEV
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
            JMP returnFromBYTEV

.LBB18      PLA
            TAX
            LDA #&00
.^returnViaParentBYTEV
.LBB1C      JSR jmpParentBYTEV
            JMP returnFromBYTEV

	  ; SFTODO: I think we could do this loop backwards to save two bytes on CPX #
.LBB22      LDX #&00								;start at offset 0
.LBB24      LDA osError,X								;relocate error code from &BB3C
            STA L0100,X								;to &100
            INX
            CPX #osErrorEnd - osError							;until &15
            BNE LBB24								;loop
            LDX #prvOsMode - prv83							;select OSMODE
            JSR readPrivateRam8300X							;read data from Private RAM &83xx (Addr = X, Data = A)
            ORA #'0'								;convert OSMODE to character printable OSMODE (OSMODE = OSMODE + &30)
            STA L0113								;write OSMODE character to error text
            JMP L0100								;Generate BRK and error

.osError	  EQUB &00,&F7
	  EQUS "OS 1.20 / OSMODE 0", &00
.osErrorEnd
}

{
.jmpParentWORDV
.LBB51      JMP (parentWORDV)

.^wordvHandler
.LBB54	  JSR restoreOrigVectorRegs
            CMP #&09
            BNE LBB67
            JSR setMemsel
            JSR jmpParentWORDV
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

; We're processing OSWRCH with A=vduSetMode. That is only actually a set mode call if we're not
; part-way through a longer VDU sequence (e.g. VDU 23,128,22,...), so check that and set
; ModeChangeState to ModeChangeStateSeenVduSetMode if we
; *are* going to change mode.
.OswrchVduSetMode
{
    PHA
    LDA negativeVduQueueSize:BNE InLongerVduSequence
    ; SQUASH: We know ModeChangeState is 0 here, so we could just do ASSERT ModeChangeStateNone
    ; + 1 == ModeChangeStateSeenVduSetMode;INC ModeChangeState.
    LDA #ModeChangeStateSeenVduSetMode:STA ModeChangeState
.InLongerVduSequence
    PLA:JMP ProcessWrchv
}

; The following scope is the WRCHV handler; the entry point is at WrchvHandler half way down.
{
; We're processing the second byte of a vduSetMode command, i.e. we will change mode when we
; forward this byte to the parent WRCHV.
.SelectNewMode
    PLA:PHA ; peek original OSWRCH A=new mode
    CMP #shadowModeOffset:BCS EnteringShadowMode
    LDA osShadowRamFlag:BEQ EnteringShadowMode
    ; We're entering a non-shadow mode.
    PLA:PHA ; peek original OSWRCH A=new mode SQUASH: redundant, maybeSwapShadow2 does LDA
    JSR maybeSwapShadow2
    LDA ramselCopy:AND_NOT ramselShen:STA ramselCopy:STA ramsel
    PLA:PHA ; peek original OSWRCH A=new mode
    AND_NOT shadowModeOffset ; SQUASH: redundant as we didn't take "BCS EnteringShadowMode" branch above
    LDX #prvSFTODOMODE - prv83:JSR writePrivateRam8300X
    LDA #ModeChangeStateEnteringNonShadowMode:STA ModeChangeState
    PLA:JMP ProcessWrchv

.EnteringShadowMode
    LDA ramselCopy:ORA #ramselShen:STA ramselCopy:STA ramsel
    JSR maybeSwapShadow1
    PLA:PHA ; peek original OSWRCH A=new mode
    ORA #shadowModeOffset:LDX #prvSFTODOMODE - prv83:JSR writePrivateRam8300X
    ; SQUASH: Share STA ModeChangeState:PLA:JMP ProcessWrchv with code above?
    LDA #ModeChangeStateEnteringShadowMode:STA ModeChangeState
    PLA:JMP ProcessWrchv

.CheckOtherModeChangeStates
    CMP #ModeChangeStateEnteringNonShadowMode
    BNE WrchvHandlerDone
    BEQ AdjustCrtcHorz

.^WrchvHandler
    JSR restoreOrigVectorRegs
    PHA
    LDA ModeChangeState:BNE SelectNewMode
    PLA
    CMP #vduSetMode:BEQ OswrchVduSetMode
.^ProcessWrchv ; SFTODO: not a great name...
    JSR setMemsel
    JSR jmpParentWRCHV
    PHA
    LDA ModeChangeState:CMP #ModeChangeStateEnteringShadowMode:BNE CheckOtherModeChangeStates
    LDA vduStatus:ORA #vduStatusShadow:STA vduStatus
.AdjustCrtcHorz
    ; DELETE: There seems to be an undocumented feature of IBOS which will perform a horizontal
    ; screen shift (analogous to the vertical shift controlled by *TV/*CONFIGURE TV) based on
    ; userRegHorzTV. This is not exposed in *CONFIGURE/*STATUS, but it *does seem to work if
    ; you use *FX162,54 to write directly to the RTC register. In a modified IBOS this should
    ; probably either be removed to save space or exposed via *CONFIGURE/*STATUS.
    LDX #userRegHorzTV:JSR readUserReg
    CLC:ADC #&62
    LDX currentMode
    CPX #4:BCC crtcHorzDisplayedInA
    LSR A
    CPX #7:BNE crtcHorzDisplayedInA
    CLC:ADC #&04
.crtcHorzDisplayedInA
    LDX #&02:STX crtcHorzTotal
    STA crtcHorzDisplayed
    LDA #ModeChangeStateNone:STA ModeChangeState
.^WrchvHandlerDone
    PLA
    JMP returnFromVectorHandler
}

{
ptr = &A8
ScreenStart = &3000

; SFTODO: The next two subroutines are probably effectively saying "do nothing
; if the shadow state hasn't changed, otherwise do SwapShadowIfShxEnabled". I
; have given them poor names for now and should revisit this once exatly when
; they're called becomes clearer.
; SFTODO: This has only one caller
.^maybeSwapShadow1
.LBC2D      LDA vduStatus								;get VDU status
            AND #vduStatusShadow							;test bit 4
            BEQ SwapShadowIfShxEnabled							;and branch if clear
            RTS

; SFTODO: This has only one caller
.^maybeSwapShadow2
.LBC34      LDA vduStatus								;get VDU status
            AND #vduStatusShadow        						;test bit 4
            ; SFTODO: Rewriting the next two lines as "BEQ some-rts-somewhere:FALLTHROUGH_TO SwapShadowIfShxEnabled" would save a byte.
            BNE SwapShadowIfShxEnabled							;and branch if clear
            RTS

; If SHX is enabled, swap the contents of main and shadow RAM between &3000-&7FFF.
; ENHANCE: If we could speed this up (e.g. by using a buffer in private RAM to swap a page at a
; time, instead of having to toggle MEMSEL twice per byte of screen memory), we could encourage
; having SHX enabled (e.g. make it the default). Acorn shadow RAM on the B+ and M128 always
; behaves as if SHX is enabled, so having it on reduces scope for surprise program corruption.
.SwapShadowIfShxEnabled
    LDX #prvShx - prv83:JSR readPrivateRam8300X:BEQ Rts ; nothing to do if SHX off
    ; Blank out the screen while we're copying data around. There's a mode change pending in
    ; the near future and that will undo this change.
    LDA #&08:STA crtcHorzTotal
    LDA #&F0:STA crtcHorzDisplayed
    ; SQUASH: Since we use EOR to toggle MEMSEL in the swap loop, couldn't we get away with not
    ; temporarily clearing PRVEN/MEMSEL and then not having to restore ROMSEL afterwards? It
    ; doesn't matter if MEMSEL is currently set or not, since the operation is symmetrical, and
    ; we'd do an even number of toggles so we'd finish in the original state.
    LDA romselCopy:PHA
    AND #maxBank:STA romselCopy:STA romsel ; temporarily clear PRVEN/MEMSEL
    LDA ptr:PHA
    LDA ptr + 1:PHA
    LDA #lo(ScreenStart):STA ptr
    LDA #hi(ScreenStart):STA ptr + 1
    LDY #0
.Loop
    LDA (ptr),Y:TAX
    LDA romselCopy:EOR #romselMemsel:STA romselCopy:STA romsel
    LDA (ptr),Y:PHA
    TXA:STA (ptr),Y
    LDA romselCopy:EOR #romselMemsel:STA romselCopy:STA romsel
    PLA:STA (ptr),Y
    INY:BNE Loop
    INC ptr + 1:BPL Loop ; loop until we hit &8000
    PLA:STA ptr + 1
    PLA:STA ptr
    PLA:STA romselCopy:STA romsel
.Rts
    RTS
}

{
.^IbosSetUp ; SFTODO: Not a great name, but will do until I fully understand the contexts it's called in - note this doesn't install *all* vectors, only the ones in Tbl1, FWIW
    LDA #0:STA ramselCopy:STA ramsel ; clear ramselShen (SFTODO: and Prvs* too; is this safe? probably...)

    ; If we're in OSMODE 0, don't install vector handlers, set up the print buffer or enable
    ; shadow RAM.
    LDX #prvOsMode - prv83:JSR readPrivateRam8300X:BEQ OsMode0
    JSR installOSPrintBufStub

    ; Save the parent values of BYTEV, WORDV, WRCHV and RDCHV at parentVectorTbl1 and install
    ; our handlers at osPrintBuf+n*3 where n=0 for BYTEV, 1 for WORDV, etc.
    PHP:SEI
    LDX #0
    LDY #lo(osPrintBuf)
.Loop
    LDA BYTEVL,X:STA parentVectorTbl1,X
    TYA:STA BYTEVL,X
    LDA BYTEVH,X:STA parentVectorTbl1+1,X
    LDA #hi(osPrintBuf):STA BYTEVH,X
    INY:INY:INY
    INX:INX
    CPX #8:BNE Loop
    PLP

    JSR InitPrintBuffer
    LDA lastBreakType:BNE DisableShadow ; branch if not soft reset
    LDX #prvSFTODOMODE - prv83:JSR readPrivateRam8300X:BPL DisableShadow
    ; Enable shadow RAM.
    LDA #ramselShen:STA ramselCopy:STA ramsel ; set ramselShen (SFTODO: and clear Prvs* too; is this safe? probably...)
    LDA vduStatus:ORA #vduStatusShadow:STA vduStatus
    LDA #ModeChangeStateNone:STA ModeChangeState
    RTS

.OsMode0
.^DisableShadow
    LDA #0:STA ramselCopy:STA ramsel ; clear ramselShen (SFTODO: and Prvs* too; is this safe? probably...)
    LDA vduStatus:AND_NOT vduStatusShadow:STA vduStatus
    LDA #ModeChangeStateNone:STA ModeChangeState
    LDA #1:STA osShadowRamFlag
.SFTODOCOMMON1
    JSR PrvEn
    LDA prvSFTODOMODE:AND_NOT shadowModeOffset:STA prvSFTODOMODE
    JMP PrvDis
}

; Enter OSMODE 0, *assuming* we are currently in a different OSMODE.
; SQUASH: This has only one caller and doesn't seem to return early so it could probably be
; inlined.
.EnterOsMode0
{
    ; Restore the original vectors.
    PHP:SEI
    LDX #7
.Loop1
    LDA parentVectorTbl1,X:STA BYTEVL,X
    ; SQUASH: Could we do something like "CPX #6:BCS skip:LDA parentVectorTbl2,X:STA
    ; INSVL,X:.skip" here and then get rid of Loop2?
    DEX:BPL Loop1
    LDX #5
.Loop2
    LDA parentVectorTbl2,X:STA INSVL,X
    DEX:BPL Loop2
    PLP

    ; Disable shadow RAM.
    ; SQUASH: I think the next few lines up to and including "JSR PrvDis" could be replaced by
    ; "JSR SFTODOCOMMON1".
    JSR PrvEn
    LDA prvSFTODOMODE:AND_NOT shadowModeOffset:STA prvSFTODOMODE
    JSR PrvDis
    JSR maybeSwapShadow2
    JMP DisableShadow
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

.InsvHandler
{
    TSX:LDA L0102,X ; get original X=buffer number
    CMP #bufNumPrinter:BEQ IsPrinterBuffer
    LDA #ibosINSVIndex:JMP forwardToParentVectorTblEntry

.IsPrinterBuffer
    JSR pageInPrvs81
    PHA
    TSX
    JSR checkPrintBufferFull:BCC PrintBufferNotFull
    ; Return to caller with carry set to indicate insertion failed.
    LDA L0107,X:ORA #flagC:STA L0107,X ; modify stacked flags so C is set
    JMP RestoreRamselClearPrvenReturnFromVectorHandler

.PrintBufferNotFull
    LDA L0108,X ; get original A=character to insert
    JSR staPrintBufferWritePtr
    JSR AdvancePrintBufferWritePtr
    JSR decrementPrintBufferFree
    ; Return to caller with carry clear to indicate insertion succeeded.
    TSX:LDA L0107,X:AND_NOT flagC:STA L0107,X ; modify stacked flags so C is clear
    JMP RestoreRamselClearPrvenReturnFromVectorHandler
}

; SQUASH: Would it be possible to factor out the common-ish code at the start of
; InsvHandler/RemvHandler/CnpvHandler to save space?
.RemvHandler
{
    TSX:LDA L0102,X ; get original X=buffernumber
    CMP #bufNumPrinter:BEQ IsPrinterBuffer
    LDA #ibosREMVIndex:JMP forwardToParentVectorTblEntry
			
.IsPrinterBuffer
    JSR pageInPrvs81
    PHA
    TSX
    JSR checkPrintBufferEmpty:BCC PrintBufferNotEmpty
    ; SQUASH: Some similarity with InsvHandler here, could we factor out common code?
    LDA L0107,X:ORA #flagC:STA L0107,X ; modify stacked flags so C is set
    JMP RestoreRamselClearPrvenReturnFromVectorHandler ; SQUASH: BNE ; always branch

; ENHANCE: The following code returns the character in Y for examine and A for remove, which is
; the wrong way round. This works in practice for the all-important case of the OS removing
; characters from the printer buffer to send to the printer because OS 1.20 expects the
; character to be in A for remove. It's pretty unlikely any non-OS code is ever going to call
; REMV on the printer buffer, but ideally we would return the character in both A and Y for
; both examine and remove. See https://stardot.org.uk/forums/viewtopic.php?f=54&p=319880.

.PrintBufferNotEmpty
    LDA L0107,X:AND_NOT flagC:STA L0107,X ; modify stacked flags so C is clear
    JSR ldaPrintBufferReadPtr
    TSX
    PHA ; note this doesn't affect X so our L01xx,X references stay the same
    LDA L0107,X:AND #flagV:BNE ExamineBuffer ; test V in stacked flags from caller
    ; V was cleared by the caller, so we're removing a character from the buffer.
    PLA:STA L0108,X ; overwrite stacked A with character read from our buffer
    JSR AdvancePrintBufferReadPtr
    JSR incrementPrintBufferFree
    JMP RestoreRamselClearPrvenReturnFromVectorHandler

.ExamineBuffer
    ; V was set by the caller, so we're just examining the buffer without removing anything.
    PLA:STA L0102,X ; overwrite stacked Y with character peeked from our buffer
    FALLTHROUGH_TO RestoreRamselClearPrvenReturnFromVectorHandler
}

; Restore RAMSEL to the stacked value, clear PRVEN, then return from the vector
; handler.
; SFTODO: Perhaps not the catchiest label name ever...
.RestoreRamselClearPrvenReturnFromVectorHandler
{
    PLA:STA ramselCopy:STA ramsel
    LDA romselCopy:AND_NOT romselPrvEn:STA romselCopy:STA romsel
    JMP returnFromVectorHandler
}

.CnpvHandler
{
    TSX:LDA L0102,X ; get original X=buffer number
    CMP #bufNumPrinter:BEQ IsPrinterBuffer
    LDA #ibosCNPVIndex:JMP forwardToParentVectorTblEntry

.IsPrinterBuffer
    LDA ramselCopy:PHA
    JSR PrvEn
    TSX:LDA L0107,X:AND #flagV:BEQ Count ; test V in stacked flags from caller
    ; We're purging the buffer.
    LDX #prvPrintBufferPurgeOption - prv83:JSR readPrivateRam8300X:BEQ PurgeOff
    JSR purgePrintBuffer
.PurgeOff
    JMP RestoreRamselClearPrvenReturnFromVectorHandler

.Count
    LDA L0107,X:AND #flagC:BNE CountSpaceLeft ; test C in stacked flags from caller
    ; We're counting the entries in the buffer; return them as 16-bit value YX.
    JSR getPrintBufferUsed
    TXA:TSX:STA L0103,X ; overwrite stacked X, so we return A to caller in X
    TYA:STA L0102,X ; overwrite stacked Y, so we return A to caller in Y
    JMP RestoreRamselClearPrvenReturnFromVectorHandler

.CountSpaceLeft
    ; We're counting the space left in the buffer; return that as 16-bit value YX.
    JSR getPrintBufferFree
    ; SQUASH: Following code is identical to fragment just above, we could JMP to it to avoid
    ; this duplication.
    TXA:TSX:STA L0103,X ; overwrite stacked X, so we return A to caller in X
    TYA:STA L0102,X ; overwrite stacked Y, so we return A to caller in Y
    JMP RestoreRamselClearPrvenReturnFromVectorHandler
}

; SQUASH: This only has one caller and doesn't seem to return early.
; SQUASH: Some of the code in here is similar to that used as part of 'buffer' (the *BUFFER
; command), could it be factored out?
.InitPrintBuffer
{
    LDX lastBreakType:BEQ softReset
    ; On hard break or power-on reset, set up the printer buffer so it uses private RAM from
    ; prvPrvPrintBufferStart onwards.
    JSR PrvEn
    LDA #0
    STA prvPrintBufferSizeLow
    STA prvPrintBufferSizeHigh
    STA prvPrintBufferFirstBankIndex
    STA prvPrintBufferBankCount
    ; SFTODO: Following code is similar to chunk just below InitialiseBuffer, could
    ; it be factored out?
    JSR SanitisePrvPrintBufferStart:STA prvPrintBufferBankStart
    LDA #&B0:STA prvPrintBufferBankEnd ; SFTODO: Magic constant ("top of private RAM")
    SEC:LDA prvPrintBufferBankEnd:SBC prvPrintBufferBankStart:STA prvPrintBufferSizeMid
    LDA romselCopy:ORA #romselPrvEn:STA prvPrintBufferBankList
    LDA #&FF
    STA prvPrintBufferBankList + 1
    STA prvPrintBufferBankList + 2
    STA prvPrintBufferBankList + 3
.softReset
    JSR purgePrintBuffer
    JSR PrvDis
    ; Copy the rom access subroutine used by the printer buffer from ROM into RAM.
    LDY #romRomAccessSubroutineEnd - romRomAccessSubroutine - 1
.SubroutineCopyLoop
    LDA romRomAccessSubroutine,Y:STA ramRomAccessSubroutine,Y
    DEY:BPL SubroutineCopyLoop

    ; Save the parent values of INSV, REMV and CNPV at
    ; parentVectorTbl2 and install our handlers at osPrintBuf+n*3 where
    ; n=4 for INSV, 5 for REMV and 6 for CNPV.
    PHP:SEI
    LDX #0
    LDY #lo(osPrintBuf + 4 * 3)
.VectorLoop
    LDA INSVL,X:STA parentVectorTbl2,X
    TYA:STA INSVL,X
    LDA INSVH,X:STA parentVectorTbl2+1,X
    LDA #hi(osPrintBuf + 4 * 3):STA INSVH,X
    INY:INY:INY
    INX:INX
    CPX #6:BNE VectorLoop
    PLP
    RTS
}

{
; Advance prvPrintBufferReadPtr by one, wrapping round at the end of each bank
; and wrapping round at the end of the bank list.
; SFTODO: This has only one caller
.^AdvancePrintBufferReadPtr
.LBEB2      LDX #prvPrintBufferReadPtrIndex
            ASSERT prvPrintBufferReadPtrIndex != 0:BNE LBEB8 ; always branch
; Advance prvPrintBufferWritePtr by one, wrapping round at the end of each bank
; and wrapping round at the end of the bank list.
; SFTODO: This has only one caller
.^AdvancePrintBufferWritePtr
.LBEB6      LDX #prvPrintBufferWritePtrIndex
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
            LDX #prvPrintBufferReadPtrIndex
            LDA #opcodeLdaAbs
            BNE LBF76 ; always branch
; Temporarily page in ROM bank prvPrintBufferBankList[prvPrintBufferWriteBankIndex] and do STA (prvPrintBufferWritePtr)
; SFTODO: This only has a single caller
.^staPrintBufferWritePtr
.LBF71      PHA
            LDX #prvPrintBufferWritePtrIndex
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
; SFTODO: Mildly magic constants
.SanitisePrvPrintBufferStart
{
    ; SQUASH: We could change "BCC Rts" below to use the RTS above and make the JSR:RTS a JMP.
    LDX #prvPrvPrintBufferStart - prv83:JSR readPrivateRam8300X
    CMP #&90:BCC UseAC
    CMP #&AC:BCC Rts
.UseAC
    LDA #&AC:JSR writePrivateRam8300X
.Rts
    RTS
}

    EQUB &00,&00,&00,&00,&00,&00,&00,&00
    EQUB &00,&00,&00,&00,&00,&00,&00,&00
    EQUB &00,&00,&00,&00,&00,&00,&00,&00
    EQUB &00,&00,&00,&00,&00,&00,&00,&00
    EQUB &00,&00,&00,&00,&00,&00,&00,&00
    EQUB &00,&00,&00,&00,&00,&00,&00,&00
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
; we're going to be modifying this in the future it might be good to put asserts
; in routines which have to live outside a certain area of the ROM in order to
; avoid breaking when we page in private RAM.

; SFTODO: I've been wrapping my multi-line comments to 95 characters (when I
; remember!), it might be nice to tweak the final disassembly to fit entirely in
; 95 columns.

; SFTODO: Enhancement idea - allow "*CO." as an abbreviation for *CONFIGURE. The Master accepts
; this, and it does trip me up when using IBOS.

; SFTODO: Minor inconsistency between "PrintBuffer" and "PrinterBuffer" in various labels

; SFTODO: *If* GXR has some incompatibilities with shadow mode on Integra-B, we could produce a
; patched GXR for it - I already have a half-decent disassembly at
; https://github.com/ZornsLemma/GXR.

;; Local Variables:
;; fill-column: 95
;; End:
