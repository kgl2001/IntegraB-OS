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
;&29:	RTC &09 - Year (Set at CopyPrvDateToRtc)
;&2A:	RTC &08 - Month (Set at CopyPrvDateToRtc)
;&2B:	RTC &07 - Day of Month (Set at CopyPrvDateToRtc)
;&2C:	RTC &06 - Day of Week (Set at CopyPrvDateToRtc)
;&2D:	RTC &04 - Hours (Set at CopyPrvTimeToRtc)
;&2E:	RTC &02 - Minutes (Set at CopyPrvTimeToRtc)
;&2F:	RTC &00 - Seconds (Set at CopyPrvTimeToRtc)
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
; SFTODO: May be worth reworking constants/comments so things like ARS0/1/2/3 and DV* are treated more like 4-bit constants than a set of 1-bit flag
rtcRegA = &0A
	rtcRegARS0 = 1<<0
	rtcRegARS1 = 1<<1
	rtcRegARS2 = 1<<2
	rtcRegARS3 = 1<<3
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
; RTC user registers to code accessing them via ReadUserReg/WriteUserReg.
;Register &32 - &04:	0-2: OSMODE / 3: SHX
;Register &35 - &13:	Century
;Register &38 - &FF:
;Register &39 - &FF:
;Register &3A - &90:
;Register &7F - &7F:	Bit set if RAM located in 32k bank. Default was &0F (lowest 4 x 32k banks). Changed to &7F

; These constants identify user registers for use with ReadUserReg/WriteUserReg;
; although some of these will be stored in RTC user registers, this is really an
; implementation detail (and an offset of rtcUserBase needs to be applied when
; accessing them, which will be handled automatically by
; ReadUserReg/WriteUserReg if necessary).
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
userRegAlarm = &33 ; SFTODO? bits 0-5?? SFTODO: bit 7 seems to be the "R" flag from *ALARM command ("repeat"???)
    userRegAlarmRepeatBit = 1 << 7
    userRegAlarmEnableBit = 1 << 6
    ; We don't have named constants for the other bits as a result of the way the code is
    ; structured, but they are:
    ;     5: amplitude (index into AlarmAmplitudeLookup)
    ;     3-4: pitch (index into AlarmPitchLookup)
    ;     1-2: alarm audio duration (index into AlarmAudioDurationLookup)
    ;     0: alarm overall duration (index into AlarmOverallDurationLookup)
userRegCentury = &35
userRegHorzTV = &36 ; "horizontal *TV" settings
userRegBankWriteProtectStatus = &38 ; 2 bytes, 1 bit per bank
userRegPrvPrintBufferStart = &3A ; the first page in private RAM reserved for the printer buffer (&90-&AC)
userRegRamPresenceFlags = &7F ; b0 set=RAM in banks 0-1, b1 set=RAM in banks 2-3, ...

; SFTODO: Very temporary variable names, this transient workspace will have several different uses on different code paths. These are for osword 42, the names are short for my convenience in typing as I introduce them gradually but they should be tidied up later.
TransientZP = &A8
TransientZPSize = 8
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
transientCommandIndex = &AA ; 1 byte SFTODO: as in other places, this is "cmd" in the sense that one of our * commands or one of our *CONFIGUURE X "things" is a "command", not *just* * commands
transientDynamicSyntaxState = &AE ; 1 byte
    ; b7 and b6 of transientDynamicSyntaxState act as flags. Since they're tested via BIT we
    ; don't have any named constants for them; see StartDynamicSyntaxGeneration for details.
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
osEscapeFlag = &FF
romActiveLastBrk = &024A
negativeVduQueueSize = &026A
tubePresenceFlag = &027A ; SFTODO: allmem says 0=inactive, is there actually a specific bit or value for active? what does this code rely on?
osShadowRamFlag = &027F ; *SHADOW option, 1=force shadow mode, 0=don't force shadow mode
currentLanguageRom = &028C ; SFTODO: not sure yet if we're using this for what the OS does or repurposing it
osfileBlock = &02EE ; OS OSFILE block for *LOAD, *SAVE, etc
currentMode = &0355

romTypeTable = &02A1
romPrivateWorkspaceTable = &0DF0

romTypeSrData = 2 ; ROM type byte used for banks allocated to pseudo-addressing via *SRDATA

CapitaliseMask = &DF
LowerCaseMask = &20

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
osfileCreateFile = &07
osfileReadInformationLengthOffset = &0A
osfileLoad = &FF

keycodeAt = &47 ; internal keycode for "@"
keycodeNone = &FF ; internal keycode returned if no key is pressed

osargsReadFilingSystemNumber = 0
    FilingSystemDfs = 4
    FilingSystemNfs = 5
osargsWritePtr = 1
osargsReadExtent = 2

osbyteSelectOutputDevice = &03
osbyteSetPrinterType = &05
osbyteSetPrinterIgnore = &06
osbyteSetSerialReceiveRate = &07
osbyteSetSerialTransmitRate = &08
osbyteSetAutoRepeatDelay = &0B
osbyteSetAutoRepeatPeriod = &0C
osbyteFlushSelectedBuffer = &15
osbyteReflectKeyboardStatusInLeds = &76
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
osbyteReadWriteSpoolFileHandle = &C7
osbyteReadWriteBreakEscapeEffect = &C8
osbyteReadWriteKeyboardStatus = &CA
osbyteReadWriteEnableDisableStartupMessage = &D7
osbyteReadWriteVduQueueLength = &DA
osbyteReadWriteOutputDevice = &EC
osbyteReadWriteShadowScreenState = &EF
osbyteReadWriteStartupOptions = &FF

oswordInputLine = &00
oswordSound = &07
oswordReadPixel = &09

shadowHimem = &8000

romBinaryVersion = &8008

oswdbtA = &EF
oswdbtX = &F0
oswdbtY = &F1

; SFTODO: These may need renaming, or they may not be as general as I am assuming
KeywordTableOffset = 6
ParameterTableOffset = 8
; SQUASH: I am not sure CmdTblPtrOffset is actually useful - every "table" holds a different
; data structure in the thing pointed to by CmdTblPtrOffset so there's no generic code which
; uses this pointer - we can just hard-code the relevant address where we need it and not lose
; any real generality.
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
transientConfigPrefix = &BD ; 0=none, 1="NO", 2="SH" - see ParseNoSh
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
serviceTubePostInitialisation = &FE

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
XFILEV      = &0DBA
XFILEVBank  = XFILEV + 2

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
tubeEntryMultibyteHostToParasite = &01
tubeEntryClaim = &C0 ; plus claim ID
tubeEntryRelease = &80 ; plus claim ID
; http://beebwiki.mdfs.net/Tube_Protocol says tube claimant ID &3F is allocated
; to "Language startup"; I suspect IBOS's use of this is technically wrong but
; as long as no one else is using it it will probably be fine, because we won't
; be trying to claim the tube while a language is starting up.
tubeClaimId = &3F
tubeReg1Status = SHEILA + &E0
tubeReg1Data = SHEILA + &E1
tubeReg2Status = SHEILA + &E2
tubeReg2Data = SHEILA + &E3
tubeReg3Status = SHEILA + &E4
tubeReg3Data = SHEILA + &E5

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
osPrintBuf  = &0880 ; &0880
osPrintBufSize = &40
L0895       = &0895
L089B       = &089B
L08AD       = &08AD
L08AE       = &08AE
L08AF       = &08AF
L08B1       = &08B1
L08B3       = &08B3
L08B5       = &08B5
L08B6       = &08B6
osFunctionKeyStartOffsets = &0B00 ; 16 bytes for *KEY0-15
osFunctionKeyStringBase = &0B01 ; offsets are from this address
osFunctionKeyFirstFreeOffset = &0B10
osFunctionKeyFirstValidOffset = &10 ; first usable byte of *KEY data is at this offset
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
prv1End     = &8400 ; exclusive
prv8Start   = &9000
prv8End     = &B000 ; exclusive

; SFTODO: The following are grouped "logically" for now, rather than by address.
; This is probably easiest to understand, and if we're going to create a table
; showing all the addresses in order later on, there's no need for these labels
; to be in physical address order. SFTODO: Might actually be in physical order, I'll see how it works out.

prvBootCommandLength = prv81 ; 0 means no *BOOT comand
prvBootCommandMaxLength = &F0 ; SFTODO MIGHT BE OFF BY ONE HERE - NOT BEEN OVER CODE THAT CAREFULLY YET
prvBootCommand = prv81 + 1
; SFTODO: I suspect there's probably the last few bytes of &81xx past the max length are free,
; but not confirmed this yet or calculated precise start address.

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
MaxPrintBufferSwrBanks = 4
; prvPrintBufferBankList is a 4 byte list of private/sideways RAM banks used by
; the printer buffer. If there are less than 4 banks, the unused entries will be
; &FF. If the buffer is in private RAM, the first entry will be &4X where X is
; the IBOS ROM bank number and the others will be &FF.
prvPrintBufferBankList  = prv83 + &18 ; 4 bytes
prvPrvPrintBufferStart = prv83 + &45 ; working copy of userRegPrvPrintBufferStart
prvPrintBufferPurgeOption = prv83 + &47 ; prvOn for *PURGE ON, prvOff for *PURGE OFF

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
prvDateSFTODO0 = prvOswordBlockCopy ; SFTODO: I think we use this for two different things so giving it different names to try to reduce confusion
prvDateSFTODOX = prvOswordBlockCopy ; SFTODO: "simple" use just as 0/&FF success/fail indicator in an OSWORD call
prvDateSFTODOQ = prvOswordBlockCopy ; SFTODO: sometimes - maybe always? - used as flags regarding validation - the meaning of the flags is changed (at least) by DateCalculation so just possibly it would be helpful to give this location a different name depending on which style of flags it contains???
prvDateSFTODOQCentury = 1<<7
prvDateSFTODOQYear = 1<<6
prvDateSFTODOQMonth = 1<<5
prvDateSFTODOQDayOfMonth = 1<<4
prvDateSFTODOQDayOfWeek = 1<<3
prvDateSFTODOQHours = 1<<2
prvDateSFTODOQMinutes = 1<<1
prvDateSFTODOQSeconds = 1<<0
prvDateSFTODOQHoursMinutesSeconds = prvDateSFTODOQHours OR prvDateSFTODOQMinutes OR prvDateSFTODOQSeconds
prvDateSFTODOQCenturyYearMonthDayOfMonth = prvDateSFTODOQCentury OR prvDateSFTODOQYear OR prvDateSFTODOQMonth OR prvDateSFTODOQDayOfMonth
prvDateSFTODO1 = prvOswordBlockCopy + 1 ; SFTODO: Use as a bitfield controlling formatting
prvDateSFTODO1b = prvOswordBlockCopy + 1 ; SFTODO: Use as a copy of "final" transientDateBufferIndex
prvDateSFTODO2 = prvOswordBlockCopy + 2
    ; The low four bits of prvDateSFTODO2 control time formatting. They're not quite a bitmap
    ; but in practice this is a reasonable way to think about them. All-bits-zero means "show nothing".
    prvDateSFTODO2TimeMask = %00001111
    prvDateSFTODO212Hour = 1<<0 ; use 12 hour clock if set
    prvDateSFTODO2NoLeadingZero = 1<<1 ; use space instead of leading zero on hours if set
    prvDateSFTODO2UseHours = 1<<2 ; show hours iff set
    prvDateSFTODO2MinutesControl = 1<<3 ; 0 => show ":" separator before minutes
                                         ; 1 and prvDateSFTODO2UseHours 0 => don't show minutes
				 ; 1 and prvDateSFTODO2UseHours 1 => show "/" separator before minutes
prvDateSFTODO3 = prvOswordBlockCopy + 3
prvDateSFTODO4 = prvOswordBlockCopy + 4 ; 2 bytes SFTODO!?
prvDateSFTODO6 = prvOswordBlockCopy + 6 ; SFTODO: I am thinking 6/7 are actually the high word of the 32-bit address at SFTODO4, and so we should probably refer to them as SFTODO4+2/3
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

; SFTODO: SHOULD PROBABLY HAVE A CONSTANT "prvOpen" OR SOMETHING =&FF FOR ALL THE DATE CALCULATION CODE

; SFTODO WIP - THERE IS SEEMS TO BE AN EXTRA COPY OF PART OF DATE/TIME "OSWORD" BLOCK MADE HERE - "prv2" PART OF NAME IS REALLY JUST TEMP
prv2Flags = prv82 + &42 ; SFTODO: should have "Date" or something in the name
prv2FlagDayOfWeek = 1<<0
prv2FlagDayOfMonth = 1<<1
prv2FlagMonth = 1<<2
prv2FlagYear = 1<<3
prv2FlagCentury = 1<<4
prv2FlagMask = %00011111 ; SFTODO: this is probably technically redundant - we could just use AND_NOT, but doing so wouldn't recreate the binary perfectly
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
prvTmp7 = prv82 + &53

prvTmp = prv82 + &52 ; 1 byte, SFTODO: seems to be used as scratch space by some code without relying on value being preserved

; These prvAlarm* addresses are initialised by alarm interrupts and then read by subsequent
; periodic interrupts during the same alarm event.
prvAlarmOverallDuration = prv82 + &72 ; alarm will auto-cancel after this time
prvAlarmAudioDuration = prv82 + &73 ; alarm audio alert will stop after this time
prvAlarmAmplitude = prv82 + &74
prvAlarmPitch = prv82 + &75
prvAlarmToggle = prv82 + &76
prvAlarmTmp = prv82 + &76 ; same address as prvAlarmToggle but used differently

; SFTODO: The following constants are maybe a bit badly named, but I didn't just want to call them "on" and "off". They are used for some booleans which are e.g. handled via ParseOnOff and PrintOnOff
prvOn = &FF
prvOff = 0

prvOsMode = prv83 + &3C ; working copy of OSMODE, initialised from relevant bits of userRegOsModeShx in service01
prvShx = prv83 + &3D ; working copy of SHX, initialised from relevant bit of userRegOsModeShx in service01 (uses prvOn/prvOff convention)
prvOsbyte6FStack = prv83 + &3E ; used as 8 bit deep stack by osbyte6FInternal
prvSFTODOTUBE2ISH = prv83 + &40
prvSFTODOTUBEISH = prv83 + &41
prvTubeReleasePending = prv83 + &42 ; used during OSWORD 42; &FF means we have claimed the tube and need to release it at end of transfer, 0 means we don't
; prvLastFilingSystem is used to track the last filing system selected, so we can preserve the current filing system on a soft reset.
prvLastFilingSystem = prv83 + &43
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

; prvLastScreenMode is the last screen mode selected. This differs from currentMode because a)
; it includes the shadow flag in bit 7 b) it isn't modified by the OS on reset. We use it to
; emulate Master-like behaviour by preserving the current mode across a soft break. SFTODO: I
; am 95% sure this is right, but be good to check all code using it later.
prvLastScreenMode = prv83 + &3F

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
MonthsPerYear = 12

; SFTODO: Define romselCopy = &F4, romsel = &FE30, ramselCopy = &37F, ramsel =
; &FE34 and use those everywhere instead of the raw hex or SHEILA+&xx we have
; now? SFTODO: Or maybe romId instead of romselCopy and ditto for ramselCopy,
; to match the Integra-B documentation, although I find those names a bit less
; intuitive personally.
crtcHorzTotal = SHEILA + &00
crtcHorzDisplayed = SHEILA + &01
systemViaBase = &40
viaRegisterB = 0
viaRegisterInterruptEnable = 14
addressableLatchMask = %1111
addressableLatchCapsLock = 6
addressableLatchShiftLock = 7
addressableLatchData0 = 0<<3
addressableLatchData1 = 1<<3

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
; SFTODO: DELETE flagI = &04
flagV = &40

romTypeService = 1 << 7
romTypeLanguage = 1 << 6
romType6502 = 2

; Convenience macro to avoid the annoyance of writing this out every time.
MACRO AND_NOT n
    AND #NOT(n) AND &FF
ENDMACRO

; The following convenience macros only save a couple of lines of code each time they're used,
; but they avoid having extra labels cluttering up the code by hiding their internal branches.

; "INCrement if Carry Set" - convenience macro for use when adding an 8-bit value to a 16-bit
; value.
MACRO INCCS x
    BCC NoCarry
    INC x
.NoCarry
ENDMACRO

; "DECrement if Carry Clear" - convenience macro for use when subtracting an 8-bit value from a
; 16-bit value.
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

; This macro asserts that the given label immediately follows the macro call. This makes
; fall-through more explicit and guards against accidentally breaking things when rearranging
; blocks of code.
MACRO FALLTHROUGH_TO label
    ASSERT P% == label
ENDMACRO

; This macro is for use in subroutines which are going to directly access PRV1, and which
; therefore must not be located in that region of this ROM.
; SFTODO: Use this everywhere appropriate, at the moment I've just sprinkled a few calls in.
; SFTODO: We could also have a debug build option where this calls a debug subroutine to
; check PRV1 is paged in.
MACRO XASSERT_USE_PRV1
    ASSERT P% >= prv1End
ENDMACRO

; SFTODO: Document? Use? Dlete?
MACRO XASSERT_USE_PRV8
    ASSERT P% < prv8Start OR P% >= prv8End
ENDMACRO

; This macro wraps "JSR PrvEn" with a sanity check that the code calling it won't be hidden by
; paging in PRVS1. (This isn't foolproof; "P%=&8500:PRVEN:JSR &8100" would be buggy but not
; caught.)
MACRO PRVEN ; SFTODO: Rename to indicate this is PRVS1 only? Also perhaps put a verb in the name?
    XASSERT_USE_PRV1
    JSR PrvEn
ENDMACRO

; This macro wraps "JSR PrvDis" with a sanity check that the code calling it won't be hidden by
; paging in PRVS1. This isn't likely to catch anything which wouldn't be caught by PRVEN, but
; it just might.
MACRO PRVDIS ; SFTODO: Rename to indicate this is PRVS1 only? Also perhaps put a verb in the name?
    XASSERT_USE_PRV1
    JSR PrvDis
ENDMACRO

; As PRVEN, but for paging in PRVS1 and PRVS8.
MACRO PRVS81EN ; SFTODO: Better name?
    XASSERT_USE_PRV1
    XASSERT_USE_PRV8
    JSR pageInPrvs81
ENDMACRO

start = &8000
end = &C000
ORG	start
GUARD	end

;ROM Header Information
.romHeader	JMP language							;00: Language entry point
		JMP service							;03: Service entry point
.romType
		EQUB romTypeService OR romTypeLanguage OR romType6502
.copyrightOffset
		EQUB copyright - romHeader						;07: Copyright offset pointer
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
.CmdRef
{
    LDX #lo(CmdRef):LDY #hi(CmdRef)
    RTS
		
		EQUS &20								;Number of * commands. Note SRWE & SRWP are not used SFTODO: I'm not sure this is entirely true - the code at SearchKeywordTable seems to use the 0 byte at the end of CmdTbl to know when to stop, and if I type "*SRWE" on an emulated IBOS 1.20 machine I get a "Bad id" error, suggesting the command is recognised (if not necessarily useful). It is possible some *other* code does use this, I'm *guessing* the *HELP display code uses this in order to keep SRWE and SRWP "secret" (but I haven't looked yet).
		ASSERT P% = CmdRef + KeywordTableOffset
		EQUW CmdTbl							;Start of * command table
		ASSERT P% = CmdRef + ParameterTableOffset
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
		EQUW SpoolOn-1							;address of *SPOOLON command
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
}
	
;Store *CONFIGURE reference table pointer address in X & Y
.ConfRef
{
    LDX #lo(ConfRef):LDY #hi(ConfRef)
    RTS

.^ConfTbla
    EQUB 17							;Number of *CONFIGURE commands
    ASSERT P% = ConfRef + KeywordTableOffset ; SFTODO: Or is this not as common-with-CmdRef parsing as I imagine?
    EQUW ConfTbl							;Start of *CONFIGURE commands lookup table
    ASSERT P% = ConfRef + ParameterTableOffset
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
    ;     n, char 1, 2, ..., n-1 	   i  ConfTbl entry		fully expanded text
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
    EQUB  5, t+19, "63>"		; 16  ALARM		"<0-63>"
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
    ASSERT P% = ibosRef + ParameterTableOffset
    EQUW ibosParTbl							;Start of IBOS options parameters lookup table (there are no parameters!)
    ; SQUASH: I am not sure we actually need the next pointer, if we make the suggested SQUASH:
    ; change in DynamicSyntaxGenerationForIbosHelpTableA.
    ASSERT P% = ibosRef + CmdTblPtrOffset
    EQUW ibosHelpTable							;Start of IBOS sub option reference lookup table

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

.ibosHelpTable
}
    ; Elements 0-3 of ibosHelpTable table correspond to the four entries at ibosTbl.
    ibosHelpTableHelpNoArgument = 4
    ibosHelpTableConfigureList = 5
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
;     C set => no match found SFTODO: and what about A/Y? service04 uses A so it's important
.SearchKeywordTable
{
KeywordLength = &AC
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
    AND #CapitaliseMask
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
    JSR FindNextCharAfterSpace
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

.DynamicSyntaxGenerationForIbosHelpTableA
{
FirstEntry = &A8
LastEntry = &A9

    PHA

    ; SQUASH: The following seems needlessly long-winded; it is probably a legacy of an earlier
    ; version where this didn't just operate on ibosRef (note that some callers redundantly
    ; call "JSR ibosRef" before calling this subroutine). We could rewrite it as:
    ;     ASL A:ASL A:TAY
    ;     LDA ibosHelpTable    ,Y:STA transientTblPtr
    ;     LDA ibosHelpTable + 1,Y:STA transientTblPtr + 1
    ;     LDA ibosHelpTable + 2,Y:STA FirstEntry
    ;     LDA ibosHelpTable + 3,Y:STA LastEntry

    ; Set transientTblPtr = transientTblPtr[CmdTblPtrOffset].
    JSR ibosRef:STX transientTblPtr:STY transientTblPtr + 1
    LDY #CmdTblPtrOffset:LDA (transientTblPtr),Y:TAX
    INY:LDA (transientTblPtr),Y:STA transientTblPtr + 1
    STX transientTblPtr ; SQUASH: Just STA in place of TAX above

    ; Copy the the four bytes starting at ibosHelpTable+4*A-on-entry into transientTblPtr and
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
    JSR CmdRef
    JMP Common
			
.^ConfRefDynamicSyntaxGenerationForTransientCmdIdx
    JSR ConfRef
.Common
    CLC
    BIT rts ; set V
    LDA transientCommandIndex
    FALLTHROUGH_TO DynamicSyntaxGenerationForAUsingYX
}

; Generate a syntax message using entry A of the keyword and (optionally) parameter sub-tables
; of the reference table (e.g. ConfRef) pointed to by YX.
;
; On entry:
;     C set => build a syntax error on the stack and generate it when vduCr is output
;     C clear => write output to screen (vduTab jumps to a fixed column for alignment)
;                V clear => prefix with two leading spaces
;                V set => no leading spaces
;     V set => don't emit parameters
;     V clear => emit parameters
.DynamicSyntaxGenerationForAUsingYX
{
    PHA
    LDA transientTblPtr + 1:PHA:LDA transientTblPtr:PHA
    STX transientTblPtr:STY transientTblPtr + 1

    JSR StartDynamicSyntaxGeneration

    ; Emit the A-th entry of the keyword sub-table.
    TSX:LDA L0103,X:PHA ; get A on entry and push it again for easy access
    LDY #KeywordTableOffset:LDA (transientTblPtr),Y:TAX
    INY:LDA (transientTblPtr),Y:TAY
    PLA
    JSR EmitEntryAFromTableYX
    LDA #vduTab:JSR EmitDynamicSyntaxCharacter

    ; Emit the A-th entry of the parameter sub-table if V is clear.
    BIT transientDynamicSyntaxState:BVS DontEmitParameters
    TSX:LDA L0103,X:PHA ; get A on entry and push it again for easy access
    LDY #ParameterTableOffset:LDA (transientTblPtr),Y:TAX
    INY:LDA (transientTblPtr),Y:TAY
    PLA
    JSR EmitEntryAFromTableYX
    LDA #vduCr:JSR EmitDynamicSyntaxCharacter

.DontEmitParameters
    PLA:STA transientTblPtr:PLA:STA transientTblPtr + 1
    PLA
.^rts
    RTS
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
    JSR EmitDynamicSyntaxCharacter
.DoneChar
    INY:CPY Tmp:BNE CharLoop
.CharLoopDone

    ; Restore everything.
    PLA:STA Tmp
    PLA:STA TableEntryPtr:PLA:STA TableEntryPtr + 1
    PLA:TAY:PLA:TAX:PLA
    RTS
}
			
; Initialise transientDynamicSyntaxState and start generating a dynamic syntax message/error.
;
; On entry:
;     C set => start building a syntax error on the stack
;     C clear => write output to screen
;                V clear => prefix with two leading spaces
;                V set => no leading spaces
; SQUASH: This only has one caller and doesn't return early.
.StartDynamicSyntaxGeneration ; SFTODO: rename?
{
    ; Stash V (&40, b6) and C (&80, b7) in transientDynamicSyntaxState with lower bits all 0.
    LDA #0:ROR A
    BVC VClear
    ORA #flagV
.VClear
    STA transientDynamicSyntaxState

    BPL GenerateToScreen ; generate to screen if C clear on entry
    ; C set on entry; start building an error on the stack.
    LDY #0
.CopyLoop
    LDA ErrorPrefix,Y:STA L0100,Y
    INY
    CMP #' ':BNE CopyLoop
    TYA:JMP SaveA

.GenerateToScreen
    ; SQUASH: V hasn't changed since we entered this routine, so BIT is redundant.
    BIT transientDynamicSyntaxState:BVS NoLeadingSpaces
    JSR printSpace:JSR printSpace
.NoLeadingSpaces
    LDA #2
.SaveA
    ORA transientDynamicSyntaxState
    STA transientDynamicSyntaxState
    RTS

.ErrorPrefix
    EQUB &00,&DC
    EQUS "Syntax: "
}

; Emit character A to the message started by StartDynamicSyntaxGeneration. X and Y are
; preserved.
.EmitDynamicSyntaxCharacter
{
; This is the physical column on screen for *HELP output, which is indented by two spaces; for
; non-indented output we start counting at 2 in StartDynamicSyntaxGeneration anyway, so we get
; the same gap but the physical column for the tab will be TabColumn - 2.
TabColumn = 12

    BIT transientDynamicSyntaxState:BPL EmitToScreen

    ; We're emitting to an error message we're building up on the stack.
    PHA:TXA:PHA
    TSX:LDA L0102,X:PHA ; get A on entry and push it again for easy access
    LDA transientDynamicSyntaxState:AND #transientDynamicSyntaxStateCountMask:TAX
    PLA:STA L0100,X
    CMP #vduCr:BNE NotCr
    LDA #0:STA L0100,X ; terminate the error message
    JMP L0100 ; and raise the error
.NotCr
    INC transientDynamicSyntaxState
    PLA:TAX:PLA
    RTS
			
.NotTab
    INC transientDynamicSyntaxState
    JMP OSASCI
.EmitToScreen
    CMP #vduTab:BNE NotTab
    TXA:PHA
    LDA transientDynamicSyntaxState:AND #transientDynamicSyntaxStateCountMask:TAX
    LDA #' '
.TabLoop
    CPX #TabColumn:BCS AtOrPastTabColumn
    JSR OSWRCH
    INX:BNE TabLoop ; always branch
.AtOrPastTabColumn
    PLA:TAX
    RTS
}
			
;Find next character after space.
;On exit A=character Y=offset for character. Carry set if end of line
;X is preserved.
{
.SkipSpace
    INY
; SQUASH: In some places we do "LDA (transientCmdPtr),Y" after alling FindNextCharAfterSpace;
; this is redundant.
; ENHANCE: It's probably not a good idea, but we *could* make IBOS use GSINIT/GSREAD where
; appropriate - this would (I think) improve handling of quotes around filenames and allow
; standard control codes (e.g. "|M") to be used.
.^FindNextCharAfterSpace
    LDA (transientCmdPtr),Y
    CMP #' ':BEQ SkipSpace
    CMP #vduCr:BEQ SecRts
    CLC
    RTS

; SQUASH: Many copies of these two instructions, can we share?
.SecRts
    SEC
    RTS

; Like FindNextCharAfterSpace, but a single comma will also be skipped (if present) after any
; spaces.
.^FindNextCharAfterSpaceSkippingComma
    JSR FindNextCharAfterSpace:BCS SecRts
    LDA (transientCmdPtr),Y
    CMP #',':BNE ClcRts
    INY
.ClcRts
    CLC
    RTS
}

;Unrecognised Star command
.service04
{
TmpCommandTailOffset = &AD
TmpCommandIndex = &AC

    JSR SetTransientCmdPtr
    JSR CmdRef:JSR SearchKeywordTable:BCC RunCommand
    ; We didn't find a match, so see if there's an "I" prefix (case-insensitive) and if so try
    ; without that.
    TAY:LDA (transientCmdPtr),Y:AND #CapitaliseMask:CMP #'I':BNE NoIPrefix
    INY ; skip the "I"
    TYA:JSR CmdRef:JSR SearchKeywordTable:BCC RunCommand
.ExitServiceCallIndirect
    LDA #4 ; SQUASH: redundant, ExitServiceCall will do PLA
    JMP ExitServiceCall
			
.NoIPrefix
    ; Check to see if this is "*X*" or "*S*".
    INY:LDA (transientCmdPtr),Y ; read the second character
    CMP #'*':BNE ExitServiceCallIndirect
    DEY:LDA (transientCmdPtr),Y:AND #CapitaliseMask ; read and capitalise the first character
    CMP #'X':BNE NotX
    JMP commandX
.NotX
    CMP #'S':BNE ExitServiceCallIndirect
    JMP commandS
			
.RunCommand
    ; Transfer control to CmdRef[CmdTblPtrOffset][X], preserving Y (the index into the next
    ; byte of the command tail after the * command).
    STY TmpCommandTailOffset
    STX TmpCommandIndex
    ; Set transientTblPtr = CmdRef[CmdTblPtrOffset].
    ; SQUASH: Since we know we're looking at CmdRef here, this is needlessly complex - we can
    ; just hard-code CmdExTbl.
    JSR CmdRef:STX transientTblPtr:STY transientTblPtr + 1
    LDY #CmdTblPtrOffset:LDA (transientTblPtr),Y:TAX
    INY:LDA (transientTblPtr),Y:STA transientTblPtr + 1
    STX transientTblPtr
    ; Push the address at transientTblPtr[X] ready to transfer control via RTS.
    LDA TmpCommandIndex:ASL A:TAY ; double TmpCommandIndex as table-entries are 16-bit
    INY:LDA (transientTblPtr),Y:PHA
    DEY:LDA (transientTblPtr),Y:PHA
    ; Record the relevant index at transientCommandIndex for use in generating a syntax error
    ; later if necessary. (transientCommandIndex == transientTblPtr so we couldn't just store
    ; this here direectly. SQUASH: If we just used a different address instead of
    ; transientTblPtr in this subroutine we could probably avoid this.)
    LDX TmpCommandIndex:STX transientCommandIndex
    LDY TmpCommandTailOffset
    RTS ; transfer control to the command
}

;*HELP Service Call
.service09
{
    JSR SetTransientCmdPtr
    LDA (transientCmdPtr),Y:CMP #vduCr:BNE CheckArgument

    ; This is *HELP with no argument.
    LDX #ibosHelpTableHelpNoArgument
.ShowHelpX
    TXA:PHA ; save X, the ibosRefSubTblA entry to show
    ; Show our ROM title and version.
    JSR OSNEWL
    LDX #title - romHeader
.TitleVersionLoop
    LDA romHeader,X:BNE PrintChar
    LDA #' ' ; convert 0 bytes in ROM header to spaces
.PrintChar
    JSR OSWRCH
    INX:CPX copyrightOffset:BNE TitleVersionLoop
    JSR OSNEWL
    ; Now show the selected ibosRefSubTblA entry.
    PLA
    JSR ibosRef ; SQUASH: Redundant; DynamicSyntaxGenerationForIbosHelpTableA does this itself
    JSR DynamicSyntaxGenerationForIbosHelpTableA
    JMP ExitServiceCallIndirect

.CheckArgument
    ; This is *HELP with an argument; see if we recognise the argument and show it if we do.
    JSR ibosRef:LDA #0:JSR SearchKeywordTable:BCC ShowHelpX
.ExitServiceCallIndirect
    JMP ExitServiceCall
}

; Return with A=Y=0 and (transientCmdPtr),Y accessing the same byte as (osCmdPtr),Y on entry.
.SetTransientCmdPtr
    CLC:TYA:ADC osCmdPtr:STA transientCmdPtr
    LDA osCmdPtr + 1:ADC #0:STA transientCmdPtr + 1
    LDA #0:TAY
    RTS

.GenerateSyntaxErrorForTransientCommandIndex
    PRVDIS
    LDA transientCommandIndex
    JSR CmdRef
    SEC
    JMP DynamicSyntaxGenerationForAUsingYX

;service entry point
.service
{
    PHA:TXA:PHA:TYA:PHA
    TSX:LDA L0103,X	; get original A=service call number
    BEQ ExitServiceCall ; do nothing if call has been claimed already
    CMP #5:BNE NotServiceCall5
    ; We're handling service call 5 - unrecognised interrupt; see if the RTC has raised an
    ; interrupt and handle it.
    LDX #rtcRegC:JSR ReadRtcRam
    CMP #rtcRegCIRQF:BCC ExitServiceCall
    JMP RtcInterruptHandler
.NotServiceCall5
    LDX #(CallTableEnd - CallTable) - 1
.LookupLoop
    CMP CallTable,X:BEQ CallHandlerX
    DEX:BPL LookupLoop
    FALLTHROUGH_TO ExitServiceCall

; Return from a service call without claiming it.
.^ExitServiceCall
    PLA:TAY:PLA:TAX:PLA
    RTS

; Return from a service call, claiming it.
.^ExitAndClaimServiceCall
    ; SQUASH: Wouldn't "PLA:TAY:PLA:TAX:PLA:LDA #0:RTS" be a byte shorter?
    TSX:LDA #0:STA L0103,X ; set stacked A to 0 to claim the call
    JMP ExitServiceCall ; SQUASH: BEQ ; always branch

.CallHandlerX
    TXA:ASL A:TAX ; double X as we have 16-bit entries at HandlerTable
    ; Push the handler address - 1 onto the stack and transfer control using RTS.
    LDA HandlerTable+1,X:PHA
    LDA HandlerTable,X:PHA
    RTS

.CallTable
    EQUB &09		; *HELP instruction expansion
    EQUB serviceConfigure	; *CONFIGURE command
    EQUB serviceStatus	; *STATUS command
    EQUB &04		; Unrecognised Star command
    EQUB &FF		; Tube system initialisation
    EQUB &10		; SPOOL/EXEC file closure warning
    EQUB &03		; Autoboot
    EQUB &01		; Absolute workspace claim
    EQUB &0F		; Vectors claimed - Service call &0F
    EQUB &06		; Break - Service call &06
    EQUB &08		; Unrecognised OSWORD call
    EQUB &07		; Unrecognised OSBYTE call
.CallTableEnd

.HandlerTable
    EQUW service09 - 1	; Address for *HELP
    EQUW service28 - 1	; Address for *CONFIGURE command
    EQUW service29 - 1	; Address for *STATUS command
    EQUW service04 - 1	; Address for Unrecognised Star command
    EQUW serviceFF - 1	; Address for Tube system initialisation
    EQUW service10 - 1	; Address for SPOOL/EXEC file closure warning
    EQUW service03 - 1	; Address for Autoboot
    EQUW service01 - 1	; Address for Absolute workspace claim
    EQUW service0F - 1	; Address for Vectors claimed
    EQUW service06 - 1	; Address for Break
    EQUW service08 - 1	; Address for unrecognised OSWORD call
    EQUW service07 - 1	; Address for unrecognised OSBYTE call
.HandlerTableEnd

    ASSERT (CallTableEnd - CallTable) * 2 == (HandlerTableEnd - HandlerTable)
}

; Generate an error using the error number and error string immediately following the "JSR RaiseError" call.
.RaiseError
{
    PRVDIS
    PLA:STA osErrorPtr:PLA:STA osErrorPtr + 1
    LDY #1 ; start at 1 because RTS pushes return address - 1 onto stack
.CopyLoop
    LDA (osErrorPtr),Y:STA L0100,Y
    BEQ CopyDone
    INY:BNE CopyLoop ; always branch
.CopyDone
    STA L0100 ; write BRK opcode (0)
    JMP L0100
}
			
; Parse "ON" or "OFF" from the command line, returning with C clear if we succeed, in which
; case A=prvOn for ON or prvOff for OFF. If parsing fails we return with C set and A=&7F. N/Z
; reflect value in A on exit.
.ParseOnOff
{
    JSR FindNextCharAfterSpace
    LDA (transientCmdPtr),Y:AND #CapitaliseMask:CMP #'O':BNE Invalid
    INY:LDA (transientCmdPtr),Y:AND #CapitaliseMask:CMP #'N':BNE NotOn
    INY
    LDA #prvOn
    CLC
    RTS
.NotOn
    CMP #'F':BNE Invalid
    ; We will accept "OF" to mean "OFF", but if the second "F" is present we skip over it.
    INY:LDA (transientCmdPtr),Y:AND #CapitaliseMask:CMP #'F':BNE Off
    INY
.Off
    LDA #prvOff
    CLC
    RTS
.Invalid
    LDA #&7F
    SEC
    RTS
}

; Print "OFF" if A=prvOff, otherwise print "ON".
.PrintOnOff
{
    PHA
    LDA #'O':JSR OSWRCH
    PLA:ASSERT prvOff == 0:BEQ Off
    LDA #'N':JMP OSWRCH
.Off
    LDA #'F':JSR OSWRCH:JMP OSWRCH
}
			
; Print A in decimal. C set on entry means no padding, C clear means right align with spaces in
; a three character field. A is preserved.
.PrintADecimal
{
Pad = &B0 ; character output in place of leading zeros
PadFlag = &B1 ; b7 clear iff "0" should be converted into "Pad"

    PHA
    LDA #0:STA PadFlag
    BCS NoPadding ; we use NUL for padding, which has the same effect
    LDA #' '
.NoPadding
    STA Pad
    PLA:PHA

    LDX #0 ; SQUASH: change to LDX #&FF and get rid of DEX/INX stuff?
    SEC
.HundredsLoop
    SBC #100
    INX
    BCS HundredsLoop
    ADC #100
    JSR PrintDigit

    LDX #0 ; SQUASH: change to LDX #&FF and get rid of DEX/INX stuff?
    SEC
.TensLoop
    SBC #10
    INX
    BCS TensLoop
    ADC #10
    JSR PrintDigit

    TAX
    INX ; SQUASH: optimisable?
    DEC PadFlag
    JSR PrintDigit
    PLA
    RTS
			
.PrintDigit
    PHA
    DEX ; SQUASH: optimisable?
    LDA Pad
    CPX #0 ; SQUASH: Could get rid of this if LDA moved before DEX
    BNE NotZero
    BIT PadFlag:BPL PrintPad
.NotZero
    DEC PadFlag
    TXA:ORA #'0'
.PrintPad
    JSR OSWRCH
    PLA
    RTS
}
			
; Parse a 32-bit integer from (transientCmdPtr),Y. The following prefixes are
; recognised:
;     "-"  negative decimal
;     "+"  positive decimal
;     "&"  hexadecimal
;     "%"  binary
; The default base is controlled by which of the entry points below is used.
;
; On exit:
;     Y is advanced past whatever was parsed; an invalid digit stops parsing but
;     is not treated as an error.
;
;     C is clear iff an integer was parsed; more precisely:
;     C V
;     0 0 => integer parsed, result in ConvertIntegerResult, low byte in A and flags reflect A
;     0 1 => not possible
;     1 0 => input was empty, nothing to parse
;     1 1 => input not empty but nothing was parsed (we will have beeped)
;            ConvertIntegerResult and A will be 0 but flags will not reflect A
;
; ENHANCE: Beeping when we fail to parse seems a little unconventional, disable this?
; SQUASH: Could we use some loops to do the four byte arithmetic?
{
Tmp = FilingSystemWorkspace + 4 ; 4 bytes
Base = FilingSystemWorkspace + 8
NegateFlag = FilingSystemWorkspace + 9
OriginalCmdPtrY = FilingSystemWorkspace + 10
FirstDigitCmdPtrY = FilingSystemWorkspace + 11

.^ConvertIntegerDefaultHex
    LDA #16:JMP ConvertIntegerDefaultBaseA ; SQUASH: "BNE ; always branch"

; SQUASH: Could we share this fragment?
.NothingToConvert
    ; Carry is already set
    CLV
    RTS

.^ConvertIntegerDefaultDecimal
    LDA #10
.^ConvertIntegerDefaultBaseA
    STA Base
    JSR FindNextCharAfterSpace:BCS NothingToConvert ; branch if carriage return
    STY OriginalCmdPtrY
    STY FirstDigitCmdPtrY
    LDA #0
    STA ConvertIntegerResult
    STA ConvertIntegerResult + 1
    STA ConvertIntegerResult + 2
    STA ConvertIntegerResult + 3
    STA NegateFlag
    LDA (transientCmdPtr),Y:CMP #'-':BNE NotNegative
    LDA #&FF:STA NegateFlag ; SQUASH: "ROR NegateFlag"? C is set after CMP and BNE not taken
    ; '-' implies decimal.
.Decimal
    LDA #10:JMP BaseInA ; SQUASH: "BNE ; always branch"
.NotNegative
    ; Check for prefixes which indicate a particular base, overriding the default.
    CMP #'+':BEQ Decimal
    CMP #'&':BNE NotHex
    LDA #16:JMP BaseInA ; SQUASH: "BNE ; always branch"
.NotHex
    CMP #'%':BNE ParseDigit
    LDA #2
.BaseInA
    STA Base
    INY:STY FirstDigitCmdPtrY
    JMP ParseDigit ; SQUASH: "BNE ; always branch"?
			
.ValidDigitInA
    ; Set ConvertIntegerResult = ConvertIntegerResult * Base + digit.
    ; Step 1) Set Tmp = ConvertIntegerResult and ConvertIntegerResult = digit.
    TAX
    LDA ConvertIntegerResult:STA Tmp
    STX ConvertIntegerResult
    LDX #0
    LDA ConvertIntegerResult + 1:STA Tmp + 1
    STX ConvertIntegerResult + 1
    LDA ConvertIntegerResult + 2:STA Tmp + 2
    STX ConvertIntegerResult + 2
    LDA ConvertIntegerResult + 3:STA Tmp + 3
    STX ConvertIntegerResult + 3
    ; Step 2) Set ConvertIntegerResult += Tmp * Base.
    LDA Base
    LDX #8 ; Base is an 8-bit value
.MultiplyLoop
    LSR A
    BCC ZeroBit
    PHA
    CLC
    LDA ConvertIntegerResult    :ADC Tmp    :STA ConvertIntegerResult
    LDA ConvertIntegerResult + 1:ADC Tmp + 1:STA ConvertIntegerResult + 1
    LDA ConvertIntegerResult + 2:ADC Tmp + 2:STA ConvertIntegerResult + 2
    LDA ConvertIntegerResult + 3:ADC Tmp + 3:STA ConvertIntegerResult + 3
    PLA
    BVS GenerateBadParameterIndirect
.ZeroBit
    ASL Tmp:ROL Tmp + 1:ROL Tmp + 2:ROL Tmp + 3
    DEX:BNE MultiplyLoop
    INY
.ParseDigit
    LDA (transientCmdPtr),Y:CMP #'Z'+1:BCC NotLowerCase
    AND #CapitaliseMask
.NotLowerCase
    SEC:SBC #'0':CMP #10:BCC DigitConverted
    SBC #('A' - 10) - '0' ; Set A = original ASCII code - 'A' + 10, so 'A' => 10, 'B' = 11, etc
    CMP #10:BCC InvalidDigit
.DigitConverted
    CMP Base:BCC ValidDigitInA
.InvalidDigit
    ; We stop parsing when we see an invalid digit but we don't consider it an error as such. SFTODO: I think this is true, but check
    BIT NegateFlag:BPL DontNegate
    SEC
    LDA #0:SBC ConvertIntegerResult    :STA ConvertIntegerResult
    LDA #0:SBC ConvertIntegerResult + 1:STA ConvertIntegerResult + 1
    LDA #0:SBC ConvertIntegerResult + 2:STA ConvertIntegerResult + 2
    LDA #0:SBC ConvertIntegerResult + 3:STA ConvertIntegerResult + 3
.DontNegate
    CPY FirstDigitCmdPtrY:BEQ NothingParsed
    CLC
    CLV
    LDA ConvertIntegerResult
    RTS
.NothingParsed
    LDA #vduBell:JSR OSWRCH
    LDA #0
    LDY OriginalCmdPtrY
    SEC
    BIT Rts ; set V
.Rts
    RTS

.GenerateBadParameterIndirect
    JMP GenerateBadParameter
}

.GenerateNotFoundError
    JSR RaiseError
    EQUB &D6
    EQUS "Not found", &00

{
.ReadPrivateRam
    JSR SetXMsb
    JSR ReadPrivateRam8300X
    JMP ClearXMsb
.WritePrivateRam
    JSR SetXMsb
    JSR WritePrivateRam8300X
.ClearXMsb
    PHA
    TXA:AND #&7F:TAX
    PLA
    RTS

.SetXMsb
    PHA
    TXA:ORA #&80:TAX
    PLA
    RTS

; Read/write A from/to user register X. A, X and Y are preserved.
; For X<=&31, the user register is held in RTC register X+rtcUserBase.
; For &32<=X<=&7F, the user register is held in private RAM at &8380+X.
; For X>=&80, these subroutines do nothing.
; SQUASH: Does the code rely on that behaviour for X>=&80?
; SQUASH: These two routines start off very similar, can we share code?
.^ReadUserReg
    CPX #&80:BCS Rts ; no-op for X>=&80
    CPX #&32:BCS ReadPrivateRam
    PHA ; SQUASH: redundant? JSR ReadRtcRam will load a value into A...
    CLC:TXA:ADC #rtcUserBase:TAX
    PLA ; SQUASH: redundant?
    JSR ReadRtcRam
    JMP CommonEnd
.^WriteUserReg
    CPX #&80:BCS Rts ; no-op for X>=&80
    CPX #&32:BCS WritePrivateRam
    PHA
    CLC:TXA:ADC #rtcUserBase:TAX
    PLA
    JSR WriteRtcRam
.CommonEnd
    PHA
    TXA:SEC:SBC #rtcUserBase:TAX ; restore original X
    PLA
    CLC ; SQUASH: Do any callers rely on this?
.Rts
    RTS
}

{
    ASSERT P% >= prv1End ; we're going to page in PRVS1

; Page in private RAM temporarily and do STA prv83,X. A, X and Y are preserved, flags reflect A
; on exit.
.^WritePrivateRam8300X
    PHP:SEI
    JSR SwitchInPrivateRAM
    STA prv83,X
    PHA ; SQUASH: move this into SwitchOutPrivateRAM
    JMP SwitchOutPrivateRAM

; Page in private RAM temporarily and do LDA prv83,X. A, X and Y are preserved, flags reflect A
; on exit.
.^ReadPrivateRam8300X
    PHP:SEI
    JSR SwitchInPrivateRAM
    LDA prv83,X
    PHA ; SQUASH: move this into SwitchOutPrivateRAM
    ; SQUASH: We could move SwitchOutPrivateRAM just after this code and fall through to it.
    JMP SwitchOutPrivateRAM

.SwitchInPrivateRAM
    PHA
    ; SFTODO: Shouldn't we be updating ramselCopy and (especially) romselCopy here? I know we
    ; have interrupts disabled but is there no risk of an NMI?
    LDA ramselCopy:AND #ramselShen:ORA #ramselPrvs1:STA ramsel
    LDA romselCopy:ORA #romselPrvEn:STA romsel
    PLA
    RTS

; This is *not* a subroutine; it expects to PLA:PLP values stacked by the caller.
.SwitchOutPrivateRAM
    ; SFTODO: See SwitchInPrivateRAM; are we taking a chance here with NMIs?
    LDA romselCopy:STA romsel
    LDA ramselCopy:STA ramsel
    PLA
    PLP
    PHA:PLA ; make flags reflect value in A on exit
    RTS
}

.SaveTransientZP
{
    LDX #TransientZPSize - 1
.Loop
    LDA TransientZP,X:PHA
    DEX:BPL Loop
    ; Copy our caller's return address onto the top of the stack so we can return successfully.
    ; SQUASH: Can't we do TSX:LDA thinkcarefully,X:PHA:LDA thinkcarefully,X:PHA:RTS?
    PHA:PHA:TSX
    LDA L0103 + TransientZPSize,X:STA L0101,X
    LDA L0104 + TransientZPSize,X:STA L0102,X
    RTS
}

; SFTODO: This currently only has one caller and could be inlined.
.RestoreTransientZP
{
    ; Move the return address pushed by our caller over the one beneath the saved copy of TransientZP.
    ; SQUASH: Can't do we TSX:PLA:STA thinkcarefully,X:PLA:STA thinkcarefully,X?
    TSX
    LDA L0101,X:STA L0103 + TransientZPSize,X
    LDA L0102,X:STA L0104 + TransientZPSize,X
    PLA:PLA
    LDX #0
.Loop
    PLA:STA TransientZP,X
    INX:CPX #TransientZPSize:BCC Loop
    RTS
}
						
; Language entry point.
.language
{
    ; Check this is normal language start up, not (e.g.) Electron soft key expansion.
    CMP #1:BEQ NormalLanguageStartUp ; SQUASH: Move this so we can fall through and BNE to another RTS
    RTS

;Set BRK Vector
.^setBrkv
    LDA #lo(BrkvHandler):STA BRKVL
    LDA #hi(BrkvHandler):STA BRKVH
    RTS

; SFTODO: Start of this code is same as L8969 - could we save a few bytes by (e.g.) setting osErrorPtr to &8000 here and testing for that in BRKV handler and skipping the error printing code in that case?
.NormalLanguageStartUp
    CLI
    CLD
    LDX #&FF:TXS
    JSR setBrkv
    LDA lastBreakType:BNE NotSoftReset
    JMP CmdLoop ; SQUASH: "BEQ ; always branch", and then we can just fall through to NotSoftReset
.NotSoftReset
    LDA #osbyteKeyboardScanFrom10:JSR OSBYTE:CPX #keycodeAt:BEQ atPressed
    JMP CmdLoop ; SQUASH: "BEQ ; always branch" and fall through to atPressed

    ; Implement IBOS reset when @ held down during (non-soft) reset.
.atPressed
    LDA #osbyteReadWriteBreakEscapeEffect:LDX #2:LDY #0:JSR OSBYTE ; Memory cleared on next reset, ESCAPE disabled
    LDX #0
.promptLoop
    LDA resetPrompt,X:BEQ promptDone
    JSR OSASCI
    INX:BNE promptLoop ; always branch
.promptDone
    ; Wait until @ is released, flush the keyboard buffer and read user response to prompt.
.releaseAtLoop
    LDA #osbyteKeyboardScanFrom10:JSR OSBYTE:CPX #keycodeAt:BEQ releaseAtLoop
    LDA #osbyteFlushSelectedBuffer:LDX #bufNumKeyboard:JSR OSBYTE
    CLI
    JSR OSRDCH:PHA
    LDA #osbyteAcknowledgeEscape:JSR OSBYTE
    PLA:AND #CapitaliseMask:CMP #'Y':BNE NotYes
    LDX #(yesStringEnd - yesString) - 1
.yesLoop
    LDA yesString,X:JSR OSWRCH:DEX:BPL yesLoop
    JMP FullReset ; SQUASH: any chance of falling through?
.NotYes
    LDA #vduCls:JSR OSWRCH
    JMP nle

.yesString
    EQUS vduCr, "seY"
.yesStringEnd
.resetPrompt
    EQUS "System Reset", vduCr, vduCr, "Go (Y/N) ? ", 0

;BRK vector entry point
.BrkvHandler
InputBuf = &700
InputBufSize = 256
    LDX #&FF:TXS
    CLI
    CLD
    ; Clear the VDU queue, so (e.g.) the first few characters of output aren't swallowed if an
    ; error occurred half-way through a VDU 23.
    LDA #osbyteReadWriteVduQueueLength:LDX #0:LDY #0:JSR OSBYTE
    LDA #osbyteAcknowledgeEscape:JSR OSBYTE
    JSR OSNEWL
    LDY #1
.ShowErrorLoop
    LDA (osErrorPtr),Y:BEQ ErrorShown
    JSR OSWRCH:INY:BNE ShowErrorLoop ; always branch
.ErrorShown
    JSR OSNEWL
.CmdLoop
    JSR PrintStar
    JSR ReadLine
    LDX #lo(InputBuf):LDY #hi(InputBuf):JSR OSCLI
    JMP CmdLoop
			
.OswordInputLineBlock
;OSWORD A=&0, Read line from input - Parameter block
    EQUW InputBuf
    EQUB InputBufSize - 1 ; maximum length excluding CR
    EQUB ' ' ; minimum acceptable ASCII value
    EQUB '~' ; maximum acceptable ASCII value
.OswordInputLineBlockEnd

; SQUASH: This only has one caller
.PrintStar
    LDA #'*':JMP OSWRCH

.ReadLine
    ; SQUASH: I don't believe this is necessary, we can just use OswordInputLineBlock directly.
    LDY #(OswordInputLineBlockEnd - OswordInputLineBlock) - 1
.CopyLoop
    LDA OswordInputLineBlock,Y:STA L0100,Y
    DEY:BPL CopyLoop
    LDA #oswordInputLine:LDX #lo(L0100):LDY #hi(L0100):JSR OSWORD
    ; SQUASH: could we BCC a nearby RTS and just fall through to acknowledge...?
    BCS AcknowledgeEscapeAndGenerateErrorIndirect
    RTS

.AcknowledgeEscapeAndGenerateErrorIndirect
.L89BF      JMP AcknowledgeEscapeAndGenerateError
}

;Start of full reset
; SFTODO: This has only one caller
.FullReset
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
	  JSR WriteUserReg								;Write to RTC clock User area. X=Addr, A=Data
            DEX
            BPL userRegLoop

FullResetPrv = &2800
            JSR InitialiseRtcTime								;Stop Clock and Initialise RTC registers &00 to &0B
            LDX #&00								;Relocate 256 bytes of code to main memory
.CopyLoop   LDA FullResetPrvTemplate,X
            STA FullResetPrv,X
            INX
            BNE CopyLoop
            JMP FullResetPrv

;This code is relocated from IBOS ROM to RAM starting at &2800
.FullResetPrvTemplate
ptr = &00 ; 2 bytes
.L89E9      LDA romselCopy								;Get current SWR bank number.
            PHA									;Save it
            LDX #maxBank								;Start at SWR bank 15
.zeroSWRLoop
	  STX romselCopy								;Select memory bank
            STX romsel
            LDA #&80								;Start at address &8000
	  JSR zeroPageAUpToC0-FullResetPrvTemplate+FullResetPrv				;Fill bank with &00 (will try both RAM & ROM)
            DEX
            BPL zeroSWRLoop								;Until all RAM banks are wiped.
            LDA #ramselShen OR ramselPrvs841						;Set Private RAM bits (PRVSx) & Shadow RAM Enable (SHEN)
            STA ramselCopy
            STA ramsel
            LDA #romselPrvEn								;Set Private RAM Enable (PRVEN) & Unset Shadow / Main toggle (MEMSEL)
            STA romselCopy
            STA romsel
            LDA #&30								;Start at shadow address &3000
	  JSR zeroPageAUpToC0-FullResetPrvTemplate+FullResetPrv				;Fill shadow and private memory with &00
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
.L8A2D	  LDX intDefault-FullResetPrvTemplate+FullResetPrv+&00,Y				;address of relocated intDefault table:		(address for data)
	  LDA intDefault-FullResetPrvTemplate+FullResetPrv+&01,Y				;address of relocated intDefault table+1:	(data)
            JSR WriteUserReg								;Write IntegraB default value to RTC User RAM
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
.ZeroLoop   LDA #&00								;Store &00
            STA (ptr),Y
            INY
            BNE ZeroLoop
            INC L0000+&01
            LDA L0000+&01
            CMP #&C0
            BNE ZeroLoop								;Until address is &C000
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
	  ASSERT (P% + 2) - FullResetPrvTemplate <= 256 ; SFTODO: +2 because as per above SFTODO I think we actually use an extra entry off the end of this table
}


; Internal implementation of Aries/Watford shadow RAM access
; (http://beebwiki.mdfs.net/OSBYTE_%266F)
;
; On entry X is a bitmap:
;     b7=0 no stack operation
;     b7=1 pop state from stack (reading), push state on stack (writing)
;     b6=0 write switch state
;     b6=1 read switch state
;     b0=0 select video RAM
;     b0=1 select program RAM
; On exit, X contains the previous switch state:
;     b0=0 video RAM
;     b0=1 program RAM
;
; This gives the following entry values for X:
;     &00 - Select video RAM
;     &01 - Select program RAM
;     &40 - Read current RAM state
;     &41 - Read current RAM state
;     &80 - Save current RAM state and select video RAM
;     &81 - Save current RAM state and select program RAM
;     &C0 - Pop and select stacked RAM state
;     &C1 - Pop and select stacked RAM state
.osbyte6FInternal
{
WorkingX = prvTmp7 ; copy of caller supplied X which we operate on
ReturnedX = prvTmp ; value returned to our caller in X
StackBit = 1 << 7
ReadBit = 1 << 6
ProgramRamBit = 1 << 0
IgnoredBits = %00111110
    ASSERT ramselShen == 1 << 7

    PHP:SEI
    PRVEN
    ; SQUASH: Just do STX in next line and avoid this? *Or* maybe rely on the fact we have this
    ; value in X to avoid needing to load this later
    TXA:STA WorkingX
    LDA ramselCopy:ROL A:PHP ; stack flags with C=ramselShen
    LDA WorkingX:AND #StackBit OR ReadBit:CMP #StackBit:BNE NotStackWrite
    PLP:PHP:ROR prvOsbyte6FStack ; push ramselShen onto the stack
    LDA WorkingX:AND_NOT StackBit OR IgnoredBits:STA WorkingX ; clear StackBit
.NotStackWrite
    ; Set ReturnedX (the value returned in X) to have ramselShen in its low bit and be all 0s
    ; otherwise. SFTODO: BeebWiki seems to imply the return value should have all the other
    ; bits of X preserved ("This gives the following entry *and return* values"), but it
    ; doesn't look as though we do, which *may* be a small incompatibility with true Watford/
    ; Aries implementations.
    PLP:LDA #0:ROL A:STA ReturnedX ; copy ramselShen to low bit of ReturnedX
    BIT WorkingX
    BVC Write ; branch if ReadBit is 0, i.e. we're writing
    BPL NonStackRead ; branch if StackBit is 0, i.e. we're not using the stack
    ; We're doing a stack read operation; pop ramselShen from the stack and move it into
    ; ProgramRamBit of WorkingX.
    ASL prvOsbyte6FStack:ROL WorkingX
.Write
    ; Set ramselShen to be a copy of ProgramRamBit from WorkingX.
    LDA ramselCopy:ROL A:ROR WorkingX:ROR A:STA ramselCopy:STA ramsel
.NonStackRead
    LDA ReturnedX:TAX ; SQUASH: Just use LDX? Or take more advantage of X being mostly untouched.
    PRVDIS
    PLP
    RTS
}
			
; Unrecognised OSBYTE call - Service call &07
;
; Note that (depending on OSMODE) we may also claim BYTEV and our code at bytevHandler will
; override the OS implementation of some OSBYTE calls; only *unrecognised* OSBYTE calls will be
; pass through via service07.
;
; If this service call is claimed, the return value of X is in oswdbtX and the return value of
; Y is the value in the Y register, which will be pulled from the stack by
; ExitAndClaimServiceCall. (Documentation on this seems confusing, but as BeebWiki points out,
; the TAX at &F17E in OS 1.20 immediately tramples on the X register on return from this
; service call and the value in X on returning from OSBYTE is taken from oswdbtX at &E7D1. Y is
; *not* loaded from oswdbtY in the OS OSBYTE code, so the contents of the actual Y register are
; returned to the caller.)
.service07
    ; Skip OSBYTE &6C and &72 handling if we're in OSMODE 0.
    ; SQUASH: CMP #0 is redundant.
    LDX #prvOsMode - prv83:JSR ReadPrivateRam8300X:CMP #0:BNE osbyte6C
    LDA oswdbtA:JMP osbyteA1

; Test for OSBYTE &6C - Select Shadow/Screen memory for direct access
.osbyte6C
{
    LDA oswdbtA:CMP #&6C:BNE osbyte72
    ; Turn non-0 X into a 1 for the following code.
    LDA oswdbtX:BEQ HaveAdjustedXInA
    LDA #1
.HaveAdjustedXInA
    ASSERT ramselShen == 1 << 7
    PHP:SEI
    ROL ramselCopy:PHP ; stash C=ramselShen
    EOR #1:ROR A ; toggle user-supplied "X" and move it into C
    LDA ramselCopy:ROR A:STA ramselCopy:STA ramsel ; set ramselShen=C
    ; Set X on exit to opposite of original ramselShen.
    LDA #0:PLP:ROL A:EOR #1:STA oswdbtX ; SFTODO: BEEBWIKI SAYS X IS PRESERVED???
    PLP
    JMP ExitAndClaimServiceCall
}
			
; Test for OSBYTE &72 - Specify video memory to use on next MODE change
; (http://beebwiki.mdfs.net/OSBYTE_%2672)
.osbyte72
{
    CMP #&72:BNE osbyteA1
    LDA #osbyteReadWriteShadowScreenState
    LDX oswdbtX:BEQ ShadowScreenStateInX
    LDX #1
.ShadowScreenStateInX
    LDY #0:JSR OSBYTE
    STX oswdbtX ; return old value of shadow screen state to caller
    JMP ExitAndClaimServiceCall
}
			
; Test for OSBYTE &A1 - Read configuration RAM/EEPROM
.osbyteA1
    CMP #&A1:BNE osbyteA2
    PLA ; discard stacked Y
    LDX oswdbtX:JSR ReadUserReg:STA oswdbtY
    PHA ; return value we just read to caller in Y
    JMP ExitAndClaimServiceCall
			
; Test for OSBYTE &A2 - Write configuration RAM/EEPROM
.osbyteA2
    CMP #&A2:BNE osbyte44
    LDX oswdbtX:LDA oswdbtY:JSR WriteUserReg							
    PLA:LDA oswdbtY:PHA ; return to caller with Y unaltered
    JMP ExitAndClaimServiceCall							
			
; Test for OSBYTE &44 - Test sideways RAM presence
.osbyte44
    CMP #&44:BNE osbyte45
    JMP osbyte44Internal
			
; Test for OSBYTE &45 (69) - Test PSEUDO/Absolute usage
.osbyte45
    CMP #&45:BNE osbyte49
    JMP osbyte45Internal
			
; Test for OSBYTE &49 (73) - Integra-B calls
; SFTODO: Rename these labels so we have something like "CheckOsbyte49" for the test and "Osbyte49" for the actual "yes, now do it"? (Not just 49, all of them.)
.osbyte49
{
prvRtcUpdateEndedOptionsMask = prvRtcUpdateEndedOptionsGenerateUserEvent OR prvRtcUpdateEndedOptionsGenerateServiceCall

    CMP #&49:BEQ osbyte49Internal
    JMP ExitServiceCall

.osbyte49Internal
    ; SQUASH: Could we use X instead of A here? Then we'd already have &49 in A and could avoid
    ; LDA #&49.
    LDA oswdbtX:CMP #&FF:BNE XNeFF
    ; It's X=&FF: test for presence of Integra-B.
    LDA #&49:STA oswdbtX ; return with X=&49 indicates Integra-B is present
    PLA:LDA romselCopy:AND #maxBank:PHA ; return IBOS bank number to caller in Y
    JMP ExitAndClaimServiceCall
.XNeFF
.L8B63
    CMP #&FE:BNE XNeFE
    ; It's X=&FE: SFTODO: WHICH MEANS DO WHAT?
    JSR osbyte49FE
    JMP ExitAndClaimServiceCall
.XNeFE
    ; ENHANCE: Any X other than &FE or &FF invokes the following code, which is a bit of a
    ; shame as it cuts down on scope for adding additional Integra-B OSBYTE calls. If this
    ; isn't documented or used in any real code we could possibly make this specific to X=&FD
    ; or something like that.

    ; For reference, the "standard" pattern for OSBYTE calls which modify a subset of bits at a
    ; location is to set the location to (<old value> AND Y) EOR X and return the old value in
    ; X. This code *doesn't* follow this pattern.
    ;
    ; This code does prvRtcUpdateEndedOptions = (((X >> 2) AND prvRtcUpdateEndedOptions) EOR X)
    ; AND %11 and returns the original value of prvRtcUpdateEndedOptions in X, preserving Y.
    ; This effectively means that if X=%abcd, %ab masks off the bits of
    ; prvRtcUpdateEndedOptions of interest and %cd toggles them, so if %ab == 0 we set
    ; prvRtcUpdateEndedOptions to %cd.
    ;
    ; We then set rtcRegBUIE iff prvRtcUpdateEndedOptions is non-0; this enables the RTC update
    ; ended interrupt iff RtcInterruptHandler has something to do when it triggers.
    LDX #prvRtcUpdateEndedOptions - prv83:JSR ReadPrivateRam8300X:PHA
    STA oswdbtY ; this is just temporary workspace and has no effect on Y returned to caller
    LDA oswdbtX:LSR A:LSR A
    AND oswdbtY
    EOR oswdbtX
    AND #prvRtcUpdateEndedOptionsMask
    JSR WritePrivateRam8300X
    LDX #rtcRegB
    CMP #0:BNE EnableUpdateEndedInterrupt
    JSR ReadRtcRam
    AND_NOT rtcRegBUIE
    JMP Common
.EnableUpdateEndedInterrupt
    JSR ReadRtcRam
    ORA #rtcRegBUIE
.Common
    JSR WriteRtcRam
    PLA:STA oswdbtX ; return original prvRtcUpateEndedOptions to caller in X
    JMP ExitAndClaimServiceCall
}

; SQUASH: Dead code
{
    LDA vduStatus
    AND #&EF
    STA vduStatus
    LDA ramselCopy
    AND #&80
    LSR A
    LSR A
    LSR A
    ORA vduStatus
    STA vduStatus
    RTS
}

; Unrecognised OSWORD call - Service call &08
;
; ENHANCE: We could implement OSWORD &0F to set the date/time, although this probably isn't all
; that big an omission. (Don't get carried away; "function 5" to set from centiseconds since
; 1900 isn't implemented on the Master.)
.service08
{
    LDA oswdbtA
    CMP #&0E:BNE service08a
    JMP osword0e
.service08a
    CMP #&42:BNE service08b
    JMP osword42
.service08b
    CMP #&43:BNE service08c
    JMP osword43
.service08c
    CMP #&49:BNE service08d
    ; Only OSWORD &49 calls with &60 <= XY?0 < &70 are claimed by IBOS.
    ; SQUASH: No point preserving Y? ExitServiceCall restores it anyway.
    TYA:PHA:LDY #0:LDA (oswdbtX),Y:TAX:PLA:TAY:TXA ; LDA (oswdbtX) preserving Y
    CMP #&60:BCC service08d
    CMP #&70:BCS service08d
    JMP osword49
.service08d
    JMP ExitServiceCall
}

;*BOOT Command
;The *BOOT parameters are stored in Private RAM at &81xx
;They are copied to *KEY10 (BREAK) and executed on a power on reset
;Checks for ? parameter and prints out details;
;Checks for blank and clears table
{
.^boot      PRVEN								;switch in private RAM
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
            STA prvBootCommand - 1,X
            INX									;get next character
            CPX #prvBootCommandMaxLength								;check if parameter is too long
            BNE L8BFE								;loop if not too long
            CLC									;otherwise set error flag
.L8C0C      LDX #&00								;wipe parameter
.L8C0E      STX prvBootCommandLength
            PRVDIS								;switch out private RAM
            BCC L8C19								;check for error
            JMP ExitAndClaimServiceCall								;Exit Service Call
			
.L8C19      JSR RaiseError								;Goto error handling, where calling address is pulled from stack

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

; *PURGE Command
.purge
{
    JSR ParseOnOff:BCC PurgeOnOrOff
    LDA (transientCmdPtr),Y:CMP #'?':BNE PurgeNow
    JSR CmdRefDynamicSyntaxGenerationForTransientCmdIdx
    LDX #prvPrintBufferPurgeOption - prv83:JSR ReadPrivateRam8300X
    JMP PrintOnOffOSNEWLExitSC

.PurgeNow
    PRVEN
    JSR PurgePrintBuffer
    JMP PrvDisExitAndClaimServiceCall

.PurgeOnOrOff
    LDX #prvPrintBufferPurgeOption - prv83:JSR WritePrivateRam8300X
    JMP ExitAndClaimServiceCall
}
			
; *BUFFER Command
; This is a big chunk of fairly self-contained code, so we use two levels of scope instead of
; the usual one to pin down the labels a bit more.
; SFTODO: "*BUFFER OFF" (at least on b-em) seems to generate an empty error message - this isn't a valid command, but this behaviour doesn't seem right
.buffer
{
TmpBankCount = L00AC
TmpTransientCmdPtrOffset = L00AD
TestAddress = &8000 ; ENHANCE: use romBinaryVersion just to play it safe

    PRVEN
    LDA prvOsMode:BNE NotOsMode0 ; the buffer isn't available in OSMODE 0
    JSR RaiseError
    EQUB &80
    EQUS "No Buffer!", &00
.NotOsMode0
    JSR ConvertIntegerDefaultDecimal:BCC BankCountParsedOK
    LDA (transientCmdPtr),Y
    CMP #'#':BEQ UseUserBankList
    CMP #'?':BNE PrvDisGenerateSyntaxError
    JMP ShowBufferSizeAndLocation
.PrvDisGenerateSyntaxError
    PRVDIS
    JMP GenerateSyntaxErrorForTransientCommandIndex

.BankCountParsedOK
{
    CMP #MaxPrintBufferSwrBanks + 1:BCC BankCountInA
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
    INX:CPX #MaxPrintBufferSwrBanks:BEQ MaxBanksFound
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
    CPX #MaxPrintBufferSwrBanks:BCS prvPrintBufferBankListInitialised
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
    ; #MaxPrintBufferSwrBanks+1? Or initialise TmpBankCount to &FF?
    LDX TmpBankCount:STA prvPrintBufferBankList,X:INX:STX TmpBankCount
    CPX #MaxPrintBufferSwrBanks:BEQ prvPrintBufferBankListInitialised2
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
    JMP PurgePrintBuffer

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
    INX:CPX #MaxPrintBufferSwrBanks:BNE CountBankLoop
    DEX
.AllBanksCounted
    LDA #&80:STA prvPrintBufferBankStart ; SFTODO: mildly magic
    LDA #0:STA prvPrintBufferFirstBankIndex
    LDA #&C0:STA prvPrintBufferBankEnd ; SFTODO: mildly magic
    STX prvPrintBufferBankCount
    JMP PurgePrintBuffer
}
			
.ShowBufferSizeAndLocation
{
    ; Divide high and mid bytes of prvPrintBufferSize by 4 to get kilobytes.
    LDA prvPrintBufferSizeHigh:LSR A
    LDA prvPrintBufferSizeMid:ROR A:ROR A
    SEC:JSR PrintADecimal
    LDA prvPrintBufferBankList:AND #&F0:CMP #&40:BNE BufferInSwr2 ; SFTODO: magic constants
    LDX #0:JSR PrintKInPrivateOrSidewaysRAM ; write 'k in Private RAM'
    JMP OSNEWLPrvDisExitAndClaimServiceCall
			
.BufferInSwr2
    LDX #1:JSR PrintKInPrivateOrSidewaysRAM ; write 'k in Sideways RAM '
    LDY #0
.ShowBankLoop
    LDA prvPrintBufferBankList,Y:BMI AllBanksShown
    SEC:JSR PrintADecimal
    LDA #',':JSR OSWRCH
    INY:CPY #MaxPrintBufferSwrBanks:BNE ShowBankLoop
.AllBanksShown
    LDA #vduDel:JSR OSWRCH ; delete the last ',' that was just printed
.*OSNEWLPrvDisExitAndClaimServiceCall
    JSR OSNEWL
.*PrvDisExitAndClaimServiceCall
    PRVDIS
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
    JSR RaiseError ; SFTODO: Change this to "GenerateError", or use "Raise" instead of "Generate" elsewhere
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
    JSR ConvertIntegerDefaultDecimal:BCC ParsedOK
    LDA (transientCmdPtr),Y:CMP #'?':BEQ ShowOsMode
    JMP GenerateSyntaxErrorForTransientCommandIndex
.ParsedOK
    JSR SetOsModeA
    JMP ExitAndClaimServiceCall
.ShowOsMode
    JSR CmdRefDynamicSyntaxGenerationForTransientCmdIdx
    LDX #prvOsMode - prv83:JSR ReadPrivateRam8300X
.^SecPrintADecimalOSNEWLPrvDisExitAndClaimServiceCall
    SEC:JSR PrintADecimal
    JMP OSNEWLPrvDisExitAndClaimServiceCall
}

.SetOsModeA
{
    CMP #0:BEQ SetOsMode0
    CMP #6:BCS GenerateBadParameterIndirect
    PHA
    PRVEN
    LDA prvOsMode:BEQ CurrentlyInOsMode0
    PLA:STA prvOsMode
.CommonEnd
    ; SQUASH: Couldn't we JMP PrvDis?
    PRVDIS
    RTS
			
.GenerateBadParameterIndirect
    JMP GenerateBadParameter

.SetOsMode0
    PRVEN
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
    JSR ConvertIntegerDefaultDecimal:BCC ParsedOK
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
    JMP GenerateSyntaxErrorForTransientCommandIndex

;*SHX Command
.shx
{
    JSR ParseOnOff:BCC ParsedOK
    LDA (transientCmdPtr),Y:CMP #'?':BNE GenerateSyntaxErrorIndirect2
    JSR CmdRefDynamicSyntaxGenerationForTransientCmdIdx
    LDX #prvShx - prv83:JSR ReadPrivateRam8300X
    JMP PrintOnOffOSNEWLExitSC
.ParsedOK
    LDX #prvShx - prv83:JSR WritePrivateRam8300X
    JMP ExitAndClaimServiceCall
}

{
;*CSAVE Command
.^csave
    LDA #osfindOpenOutput:JSR ParseFilenameAndOpen:TAY
    LDX #0
.SaveLoop
    JSR ReadUserReg:JSR OSBPUT
    INX:BPL SaveLoop ; write 128 bytes
    BMI CloseAndExit ; always branch

;*CLOAD Command
.^cload
    LDA #osfindOpenInput:JSR ParseFilenameAndOpen:TAY
    LDX #0
.LoadLoop
    JSR OSBGET:JSR WriteUserReg
    INX:BPL LoadLoop ; read 128 bytes
.CloseAndExit
    JSR CloseTransientFileHandle
    JMP ExitAndClaimServiceCall
}

;*TUBE Command
.tube
{
    JSR ParseOnOff:BCC TurnTubeOnOrOff
    LDA (transientCmdPtr),Y:CMP #'?':BNE GenerateSyntaxErrorIndirect
    JSR CmdRefDynamicSyntaxGenerationForTransientCmdIdx
    LDA tubePresenceFlag
.^PrintOnOffOSNEWLExitSC
    JSR PrintOnOff
    JSR OSNEWL
.ExitAndClaimServiceCallIndirect
    JMP ExitAndClaimServiceCall
.GenerateSyntaxErrorIndirect
    JMP GenerateSyntaxErrorForTransientCommandIndex
.TurnTubeOnOrOff
    BNE TurnTubeOn
    BIT tubePresenceFlag:BPL ExitAndClaimServiceCallIndirect ; nothing to do if already off
    ; SFTODO: We seem to be using currentLanguageRom if b7 clear, otherwise we take the bank number from romsel (which will be our bank, won't it) - not sure what's going on exactly
    LDA currentLanguageRom:BPL L8FBF
    LDA romselCopy:AND #maxBank
.L8FBF
    PHA:JSR DisableTube:PLA
    TAX:JMP DoOsbyteEnterLanguage

.^DisableTube
    LDA #0:LDX #prvSFTODOTUBE2ISH - prv83:JSR WritePrivateRam8300X
    LDA #&FF:LDX #prvSFTODOTUBEISH - prv83:JSR WritePrivateRam8300X
    LDA #0:STA tubePresenceFlag
    ; Re-select the current filing system.
    LDA #osargsReadFilingSystemNumber:LDX #TransientZP:LDY #0:JSR OSARGS ; SQUASH: don't set X?
    TAY:LDX #serviceSelectFilingSystem:JSR DoOsbyteIssueServiceRequest
    LDA #0:LDX #prvSFTODOTUBEISH - prv83:JMP WritePrivateRam8300X

.TurnTubeOn
    LDA #&81:STA tubeReg1Status
    LDA tubeReg1Status:LSR A:BCS EnableTube
    JSR RaiseError
    EQUB &80
    EQUS "No Tube!", &00

;Initialise Tube
; SFTODO: Some code in common with DisableTube here (OSARGS/filing system reselection), could factor it out
.EnableTube
    BIT tubePresenceFlag:BMI ExitAndClaimServiceCallIndirect
    LDA #&FF:LDX #prvSFTODOTUBE2ISH - prv83:JSR WritePrivateRam8300X
    LDX #prvSFTODOTUBEISH - prv83:JSR WritePrivateRam8300X
    LDX #&FF:LDY #0:JSR DoOsbyteIssueServiceRequest
    LDA #&FF:STA tubePresenceFlag
    LDX #serviceTubePostInitialisation:LDY #0:JSR DoOsbyteIssueServiceRequest
    LDA #osargsReadFilingSystemNumber:LDX #&A8:LDY #&00:JSR OSARGS:TAY ; SQUASH: Don't LDX?
    LDX #serviceSelectFilingSystem:JSR DoOsbyteIssueServiceRequest
    LDA #0:LDX #prvSFTODOTUBEISH - prv83:JSR WritePrivateRam8300X
    LDA #&7F
.TubeReg2Full
    BIT tubeReg2Status:BVC TubeReg2Full
    STA tubeReg2Data
    JMP L0032 ; SFTODO!?

.DoOsbyteIssueServiceRequest
    LDA #osbyteIssueServiceRequest:JMP OSBYTE
}

{
    ASSERT P% >= prv1End ; we're going to page in PRVS1

; Page in PRVS1.
; SFTODO: Is there any chance of saving space by sharing some code with the
; similar pageInPrvs81?
.pageInPrvs1
; SFTODO: I'd like to get rid of the PrvEn label and just use pageInPrvs1 but
; won't do it just yet, as I don't fully understand the model the code is using
; to manage paging private RAM in/out.
.^PrvEn
    PHA
    LDA ramselCopy:ORA #ramselPrvs1:STA ramselCopy:STA ramsel
    LDA romselCopy:ORA #romselPrvEn:STA romselCopy:STA romsel
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
.^PrvDis
    PHA
    LDA romselCopy:AND_NOT romselPrvEn:STA romselCopy:STA romsel
    LDA ramselCopy:AND_NOT ramselPrvs1:STA ramselCopy:STA ramsel
    PLA
    RTS
}

{
; Execute '*S*' command. This is intended for running languages (particularly non-tube
; compatible ones in PALPROMs) conveniently. It disables the tube (if present), enters OSMODE
; 4, forces shadow mode and SHX on, re-selects the current mode (thereby entering shadow mode
; if we weren't currently in one) and the executes whatever follows *S*. If that command
; returns (which it won't, if it *is* a language), we enter the NLE if we had to disable the
; tube, otherwise we return normally.
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
    JSR FindNextCharAfterSpace
    ; Push the address of the command tail onto the stack ready for CallSubCommand below.
    CLC:TYA:ADC transientCmdPtr:PHA
    LDA transientCmdPtr + 1:ADC #0:PHA
    TSX:LDA L0103,X ; get stacked flags from earlier PHP
    ASSERT flagC == 1:LSR A:BCS CommandSSetup ; branch if C set in stacked flags
    LDX #&80:JSR osbyte6FInternal ; push current RAM state and select video RAM
    JMP CallSubCommand
			
.CommandSSetup
    LDA #4:JSR SetOsModeA
    LDA #0:STA osShadowRamFlag
    LDX #prvShx - prv83:LDA #prvOn:JSR WritePrivateRam8300X ; set SHX on
    LDA #vduSetMode:JSR OSWRCH:LDA currentMode:JSR OSWRCH
    BIT tubePresenceFlag:BPL NoTube
    JSR DisableTube
    TSX:LDA L0103,X:ORA #flagV:STA L0103,X ; set V in stacked flags to indicate tube disabled
    LDA romselCopy:AND #maxBank:STA currentLanguageRom
    JSR setBrkv

.NoTube
.CallSubCommand
    PLA:TAY:PLA:TAX:JSR OSCLI
    PLP
    BCS CheckVAfterCommandS
    LDX #&C0:JSR osbyte6FInternal ; pop and select stacked shadow RAM state
.ExitAndClaimServiceCallIndirect
    JMP ExitAndClaimServiceCall

.CheckVAfterCommandS
    BVC ExitAndClaimServiceCallIndirect
    FALLTHROUGH_TO nle
}

;*NLE Command
.nle
{
    ; Enter IBOS as a language ROM.
    LDX romselCopy
.^DoOsbyteEnterLanguage
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
    JSR ConvertIntegerDefaultHex:BCC ConvertedOK
    JMP GenerateSyntaxErrorForTransientCommandIndex
.ConvertedOK
    LDA (transientCmdPtr),Y
    CMP #')':BNE NoCloseBracket
    INY
.NoCloseBracket
    JSR FindNextCharAfterSpace
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

    LDA #osfindOpenUpdate:JSR ParseFilenameAndOpen
    LDA #0:STA LineNumber
    PRVEN

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
    PRVDIS
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
    LDA LineNumber:CLC:JSR PrintADecimal
    LDA #':':JSR OSWRCH
.^printSpace
    LDA #' ':JMP OSWRCH
}
			
; *PRINT command
; Note that this sends the file to the printer, *unlike* the Master *PRINT command which is
; like *TYPE but without control code pretty-printing.
.print
{
OriginalOutputDeviceStatus = TransientZP + 1

    LDA #osfindOpenInput:JSR ParseFilenameAndOpen
    ; SQUASH: We could just read/write &27C directly
    LDA #osbyteReadWriteOutputDevice:LDX #0:LDY #&FF:JSR OSBYTE
    STA OriginalOutputDeviceStatus
    ; Disable screen drivers, enable printer, disable *SPOOL
    LDA #osbyteSelectOutputDevice:LDX #%00011010:LDY #0:JSR OSBYTE
.Loop
    BIT osEscapeFlag:BMI Escape
    LDY transientFileHandle:JSR OSBGET:BCS Eof
    JSR OSASCI
    JMP Loop
.Eof
    JSR CleanUp
    JMP ExitAndClaimServiceCall
.Escape
    JSR CleanUp
.^AcknowledgeEscapeAndGenerateError
    LDA #osbyteAcknowledgeEscape:JSR OSBYTE
    JSR RaiseError
    EQUB &11
    EQUS "Escape", &00
.CleanUp
    LDA #osbyteSelectOutputDevice:LDX OriginalOutputDeviceStatus:LDY #0:JSR OSBYTE
    JMP CloseTransientFileHandle
}
			
;*SPOOLON Command
.SpoolOn
{
    LDA #osfindOpenUpdate:JSR ParseFilenameAndOpen:TAY
    ; SFTODO: Should the next line be LDX #L00AB? X is the address of a four byte zero page
    ; control block; &AB would be a legitimate location (it's transient ZP workspace), but it's
    ; not obvious to me that &AB will *contain* a suitable location, we could trample over
    ; anything if it is arbitrary. In *practice* &AB might (from playing in b-em, not analysing
    ; code) contain &81, which would mean we're trampling over language ZP workspace but we'll
    ; get away with it in BASIC as that's part of the user ZP.
    LDX L00AB:LDA #osargsReadExtent:JSR OSARGS
    LDA #osargsWritePtr:JSR OSARGS
    ; SQUASH: We could just poke the OS workspace directly at &257.
    LDA #osbyteReadWriteSpoolFileHandle:LDX transientFileHandle:LDY #0:JSR OSBYTE
    JMP ExitAndClaimServiceCall
}
			
			
;get start and end offset of file name, store at Y & X
;convert file name offset to address of file name and store at location defined by X & Y
;then open file with file name at location defined by X & Y
.ParseFilenameAndOpen
{
    PHA ; save open mode
    JSR ParseFilename
    CLC:TYA:ADC transientCmdPtr:TAX
    LDA #0:ADC transientCmdPtr + 1:TAY
    PLA:JSR OSFIND:CMP #0:BNE OpenedOK
    JMP GenerateNotFoundError
.OpenedOK
    STA transientFileHandle
    RTS

; Parse filename at (transientCmdPtr),Y, returning with X=index to resume parsing after the
; filename and Y=index of start of filename.
.^ParseFilename
    JSR FindNextCharAfterSpace:LDA (transientCmdPtr),Y:CMP #vduCr:BNE HaveFilename
.^GenerateSyntaxErrorForTransientCommandIndexIndirect
    JMP GenerateSyntaxErrorForTransientCommandIndex
.HaveFilename
    TYA:PHA
.Loop
    LDA (transientCmdPtr),Y
    CMP #' ':BEQ EndOfFilename
    ; SFTODO: Won't we return with X pointing *after* vduCr, which would mean *CREATE will
    ; parse random junk?
    CMP #vduCr:BEQ EndOfFilename
    INY:BNE Loop ; always branch
.EndOfFilename
    TYA:TAX:INX ; end of file name offset + 1
    PLA:TAY ; start of file name offset
    RTS
}
			
			
; Close file with handle transientFileHandle.
.CloseTransientFileHandle
    LDA #osfindClose:LDY transientFileHandle:JMP OSFIND

;*CREATE Command
.create
    JSR ParseFilename
    ; Set filename in OSFILE block.
    CLC:TYA:ADC transientCmdPtr:STA osfileBlock
    LDA transientCmdPtr + 1:ADC #0:STA osfileBlock + 1
    ; Set "start address" in OSFILE block (0).
    LDA #0:STA osfileBlock + 10:STA osfileBlock + 11:STA osfileBlock + 12:STA osfileBlock + 13
    ; Set "end address" in OSFILE block (length).
    TXA:TAY:JSR ConvertIntegerDefaultHex:BCS GenerateSyntaxErrorForTransientCommandIndexIndirect
    LDA ConvertIntegerResult:STA osfileBlock + 14
    LDA ConvertIntegerResult + 1:STA osfileBlock + 15
    LDA ConvertIntegerResult + 2:STA osfileBlock + 16
    LDA ConvertIntegerResult + 3:STA osfileBlock + 17
    LDA #osfileCreateFile:LDX #lo(osfileBlock):LDY #hi(osfileBlock):JSR OSFILE
    JMP ExitAndClaimServiceCall

; *CONFIGURE and *STATUS simply issue the corresponding service calls, so the
; bulk of their implementation is in the service call handlers. This means that third-party
; ROMs which support these service calls will get a chance to add their own *CONFIGURE and
; *STATUS options, just as they could on a Master.
{
;*CONFIGURE Command
.^config
    LDX #serviceConfigure:BNE Common ; always branch

;*STATUS Command
.^status
    LDX #serviceStatus
.Common
    JSR FindNextCharAfterSpace
    LDA #&FF:PHA
    LDA (transientCmdPtr),Y:CMP #vduCr:BNE HaveArgument
    PLA:LDA #0:PHA
.HaveArgument
    TXA:PHA
    LDA transientCmdPtr:STA osCmdPtr
    LDA transientCmdPtr + 1:STA osCmdPtr + 1
    PLA:TAX ; X is serviceConfigure or serviceStatus as appropriate
    LDA #osbyteIssueServiceRequest:JSR OSBYTE
    PLA:BEQ ExitAndClaimServiceCallIndirect ; branch if we have no argument
    ; Documentation on these service calls seems a bit thin on the ground, but it looks as
    ; though they return with X=0 if a ROM recognised the argument.
    CPX #0:BEQ ExitAndClaimServiceCallIndirect ; SQUASH: TXA instead of CPX #0
.^GenerateBadParameter
    JSR RaiseError
    EQUB &FE
    EQUS "Bad parameter", &00

.ExitAndClaimServiceCallIndirect ; SQUASH: Re-use the JMP to this above
    JMP ExitAndClaimServiceCall
}

; Check next two characters of command line:
;     "NO" => C clear, transientConfigPrefix=1, Y advanced past "NO"
;     "SH" => C clear, transientConfigPrefix=2, Y advanced past "SH"
;     otherwise C set, transientConfigPrefix=0, Y preserved
.ParseNoSh
{
    TYA:PHA
    LDA (transientCmdPtr),Y:AND #CapitaliseMask:CMP #'N':BNE NotNo
    INY:LDA (transientCmdPtr),Y:AND #CapitaliseMask:CMP #'O':BNE NoMatch
    INY
    LDA #1
.Match
    STA transientConfigPrefix
    PLA ; discard stacked original Y
    CLC
    RTS
.NotNo
    CMP #'S':BNE NoMatch
    INY:LDA (transientCmdPtr),Y:AND #CapitaliseMask:CMP #'H':BNE NoMatch
    INY
    LDA #2:JMP Match ; SQUASH: "BNE ; always branch"
.NoMatch
    LDA #0:STA transientConfigPrefix
    PLA:TAY ; restore original Y
    SEC
    RTS
}

; Print ""/"NO"/"SH" (using PrintNoSh) followed by the name of the TransientCmdIdx ConfRef
; entry and a newline. This is used to display things like "SHCAPS" or "NOBOOT".
.PrintNoShWithConfRefTransientCmdIdxAndNewLine
{
    JSR PrintNoSh
    JSR ConfRefDynamicSyntaxGenerationForTransientCmdIdx
    JMP OSNEWL

; Inverse of ParseNoSh; prints "" (A=0), "NO" (A=1) or "SH" (A=2).
.PrintNoSh
    CMP #0:BNE Not0 ; SQUASH: TAX instead of CMP #0, BEQ to a nearby RTS
    RTS
.Not0
    CMP #2:BEQ Sh
    LDA #'N':JSR OSWRCH
    LDA #'O':JMP OSWRCH
.Sh
    LDA #'S':JSR OSWRCH
    LDA #'H':JMP OSWRCH
}

; *Configure parameters are stored using the following format
; EQUB Register,Start Bit,Number of Bits
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
		EQUW ConfTV - 1							;TV <0-255>,<0-1>		Type 4:
		EQUW Conf5-1							;MODE (<0-7>/<128-135>)	Type 5: 
		EQUW Conf6-1							;TUBE /NOTUBE		Type 6: Optional NO Prefix
		EQUW Conf6-1							;BOOT /NOBOOT		Type 6: Optional NO Prefix
		EQUW Conf6-1							;SHX /NOSHX		Type 6: Optional NO Prefix
		EQUW Conf1-1							;OSMODE	<0-4>		Type 1: Number starting 0
		EQUW Conf1-1							;ALARM <0-63>		Type 1: Number starting 0

; bitMaskTable[X] contains bit mask for an n-bit value; X=0 is used to represent the mask for an 8-bit value.
.bitMaskTable
    EQUB %11111111
    EQUB %00000001
    EQUB %00000011
    EQUB %00000111
    EQUB %00001111
    EQUB %00011111
    EQUB %00111111
    EQUB %01111111


.ShiftALeftByX
{
    CPX #0:BEQ Rts
.Loop
    ASL A
    DEX:BNE Loop
.Rts
    RTS
}
IF FALSE
; SQUASH: Saves two bytes, but doesn't guarantee X=0 on return - that may well not matter
.ShiftALeftByXAlternate
{
.Loop
    DEX:BMI Rts ; e.g. there's one at L93C2
    ASL A
    JMP Loop
}
ENDIF

; SQUASH: This only has a single caller
; SQUASH: Use similar code to ShiftALeftByXAlternate above?
.ShiftARightByX
{
    CPX #0:BEQ Rts
.Loop
    LSR A
    DEX:BNE Loop
.Rts
    RTS
}

.SetYToTransientCmdIdxTimes3
    LDA transientCommandIndex
    ASL A
    ADC transientCommandIndex
    TAY
    RTS

{
.GetShiftedBitMask
    LDA ConfParBit + ConfParBitBitCountOffset,Y
    AND #&7F ; SFTODO: so what does b7 signify?
    TAX:LDA bitMaskTable,X:STA transientConfigBitMask ; SQUASH: use PHA?
    LDA ConfParBit + ConfParBitStartBitOffset,Y:TAX ; SQUASH: we could just do LDX ...,Y
    LDA transientConfigBitMask ; SQUASH: use PLA?
    JSR ShiftALeftByX
    STA transientConfigBitMask
    RTS

.^SetConfigValueA
    STA transientConfigPrefix
.^SetConfigValueTransientConfigPrefix
    JSR SetYToTransientCmdIdxTimes3
    JSR GetShiftedBitMask
    LDA ConfParBit + 1,Y:TAX ; SQUASH: LDX blah,Y?
    LDA transientConfigPrefix:JSR ShiftALeftByX:AND transientConfigBitMask:STA transientConfigPrefix
    LDA transientConfigBitMask:EOR #&FF:STA transientConfigBitMask
    LDA ConfParBit + ConfParBitUserRegOffset,Y:TAX ; SQUASH: avoid this with LDX blah,Y?
    JSR ReadUserReg:AND transientConfigBitMask:ORA transientConfigPrefix:JMP WriteUserReg

.^GetConfigValue
    JSR SetYToTransientCmdIdxTimes3
    JSR GetShiftedBitMask
    LDA ConfParBit + ConfParBitUserRegOffset,Y:TAX ; SQUASH: can we just use LDX blah,Y to avoid this?
    JSR ReadUserReg:AND transientConfigBitMask:STA transientConfigPrefixSFTODO ; SQUASH: Just PHA?
    LDA ConfParBit+1,Y:TAX ; SQUASH: LDX blah,Y
    LDA transientConfigPrefixSFTODO:JSR ShiftARightByX:STA transientConfigPrefixSFTODO ; SQUASH: LDA->PLA?
    RTS
}
			
; SFTODO: This code saves transientCommandIndex (&AA) across call to ConfRefDynamicSyntaxGenerationForTransientCmdIdx, but it superficially looks as though ConfRefDynamicSyntaxGenerationForTransientCmdIdx preserves it itself, so the code to preserve here may be redundant.
.PrintConfigNameAndGetValue ; SFTODO: name is a bit of a guess as I still haven't been through the "dynamic syntax generation" (which is presumably slightly misnamed at least, as at least some of our callers would just want the option name with no other fluff) code properly
    LDA transientCommandIndex:PHA
    JSR ConfRefDynamicSyntaxGenerationForTransientCmdIdx
    PLA:STA transientCommandIndex
    JSR GetConfigValue
    LDA transientConfigPrefix
    RTS

{
; Service call &29: *STATUS Command
.^service29
    CLC:BCC Common ; always branch

; Service call &28: *CONFIGURE Command
.^service28
    SEC
.Common
    PHP
    JSR SetTransientCmdPtr
    LDA (transientCmdPtr),Y:CMP #vduCr:BNE OptionSpecified
    ; There's no option specified.
    PLP:BCC StatusAll
    ; This is *CONFIGURE with no option, so show the supported options.
    LDA #ibosHelpTableConfigureList
    JSR ibosRef ; SQUASH: Redundant - DynamicSyntaxGenerationForIbosHelpTableA does JSR ibosRef itself...
    JSR DynamicSyntaxGenerationForIbosHelpTableA
    JMP ExitServiceCall
			
.OptionSpecified
    LDA #0:STA transientConfigPrefix
    JSR ConfRef:JSR SearchKeywordTable:BCC OptionRecognised
    TAY
    JSR ParseNoSh:BCS NotNoSh
    TYA:JSR ConfRef:JSR SearchKeywordTable:BCC OptionRecognised
.NotNoSh
    PLP
    JMP ExitServiceCall
			
.OptionRecognised
    JSR FindNextCharAfterSpace
    PLP:JSR JmpConfTypTblX
    JMP ExitAndClaimServiceCall
			
; Jump to the code at ConfTypTbl[X]; C is preserved, as it is used to indicate
; *STATUS (clear) or *CONFIGURE (set).
.JmpConfTypTblX
    PHP
    STX transientCommandIndex
    TXA:ASL A:TAX
    PLP
    LDA ConfTypTbl + 1,X:PHA
    LDA ConfTypTbl,X:PHA
    RTS
			
.StatusAll
    LDX #0
.StatusLoop
    TXA:PHA:TYA:PHA
    CLC:JSR JmpConfTypTblX ; C clear => *STATUS
    PLA:TAY:PLA:TAX
    INX:CPX ConfTbla:BNE StatusLoop ; CPX against number of *CONFIGURE options SQUASH: CPX #that value
    JMP ExitServiceCall ; SQUASH: "BEQ to copy of this instruction above ; always branch"
}

;Read / Write *CONF. FILE parameters
.Conf0	
{
    BCS Conf0Write

;Read *CONF. FILE parameters from RTC register and write to screen
    JSR PrintConfigNameAndGetValue
    JSR PrintADecimalNoPad
    ; Show the D(FS)/N(FS) setting specific to *CONFIGURE FILE.
    JSR printSpace
    LDX #userRegDiscNetBootData:JSR ReadUserReg
    LDX #'N'
    AND #1:BEQ ReadNfs ; SQUASH: LSR A:BCC ReadNfs
    LDX #'D'
.ReadNfs
    TXA:JSR OSWRCH
    JMP OSNEWL

;Write *CONF. FILE parameters to RTC register
.Conf0Write
    JSR ConvertIntegerDefaultDecimalChecked:STA transientConfigPrefix
    TYA:PHA
    JSR SetConfigValueTransientConfigPrefix ; SFTODO: I'm thinking "transientConfigPrefix" might be badly misnamed (in general, not just here)
    PLA:TAY
    JSR FindNextCharAfterSpace:LDA (transientCmdPtr),Y:AND #CapitaliseMask
    ; SQUASH: Re-use another RTS here and fall through.
    CMP #'N':BEQ WriteNfs
    CMP #'D':BEQ WriteDfs ; C will be set if we branch
    RTS
.WriteNfs
    CLC
.WriteDfs
    PHP
    LDX #userRegDiscNetBootData:JSR ReadUserReg
    LSR A:PLP:ROL A
    JMP WriteUserReg
}
			
;Read / Write *CONF. <option> <n> parameters
.Conf1
{
    BCS Conf1Write
    JSR PrintConfigNameAndGetValue
    JMP PrintADecimalNoPadNewline
			
.Conf1Write
    JSR ConvertIntegerDefaultDecimalChecked
    JMP SetConfigValueA ; SQUASH: move Conf1 block so we can fall through?
}
			
; SQUASH: If we moved this to just before PrintADecimal we could fall through into it
.PrintADecimalNoPad
    SEC:JMP PrintADecimal

.PrintADecimalNoPadNewline
    JSR PrintADecimalNoPad
    JMP OSNEWL

.ConvertIntegerDefaultDecimalChecked
{
    JSR ConvertIntegerDefaultDecimal
    BCS GenerateBadParameterIndirect ; SQUASH: BCC some-other-rts and fall through
    RTS
			
.GenerateBadParameterIndirect
    JMP GenerateBadParameter
}


; SQUASH: If we moved this block just before PrintNoShWithConfRefTransientCmdIdxAndNewLine we
; could "BXX PrintNoShWithConfRefTransientCmdIdxAndNewLine ; always branch" instead of having
; to JMP.
{
; Given a ParseNoSh result n, BitLookup[n] is the bit set in the *CONFIGURE CAPS bits.
.BitLookup
    EQUB %100 ; 0 = CAPS
    EQUB %010 ; 1 = NOCAPS
    EQUB %001 ; 2 = SHCAPS

.^Conf3
    BCS Conf3Write
    JSR GetConfigValue
    LSR A:BCS ShCaps
    LSR A:BCS NoCaps
    ; SQUASH: We could omit LDA #0 and JMP into PrintNoShWithConfRefTransientCmdIdxAndNewLine
    ; after JSR PrintNoSh.
    LDA #0:JMP PrintNoShWithConfRefTransientCmdIdxAndNewLine ; CAPS
.NoCaps
    LDA #1:JMP PrintNoShWithConfRefTransientCmdIdxAndNewLine ; NOCAPS
.ShCaps
    LDA #2:JMP PrintNoShWithConfRefTransientCmdIdxAndNewLine ; SHCAPS
			
.Conf3Write
    LDX transientConfigPrefixSFTODO
    LDA BitLookup,X
    JMP SetConfigValueA
}

.Conf6
{
    BCS Conf6Write
    JSR GetConfigValue
    LDA ConfParBit + 2,Y
    ASL A:LDA #0:ROL A
    EOR transientConfigPrefixSFTODO
    JMP PrintNoShWithConfRefTransientCmdIdxAndNewLine
			
.Conf6Write
    JSR SetYToTransientCmdIdxTimes3
    ; SQUASH: Next few lines are common to read case above, factor out?
    LDA ConfParBit + 2,Y
    ASL A:LDA #0:ROL A
    EOR transientConfigPrefixSFTODO
    JMP SetConfigValueA
}

.Conf2
{
    BCS Conf2Write
    JSR GetConfigValue
    PHA:JSR ConfRefDynamicSyntaxGenerationForTransientCmdIdx:PLA
    CLC:ADC #1
    JMP PrintADecimalNoPadNewline

.Conf2Write
    JSR ConvertIntegerDefaultDecimalChecked
    SEC:SBC #1
    JMP SetConfigValueA
}

.Conf5
{
    BCS Conf5Write
    JSR GetConfigValue
    PHA:JSR ConfRefDynamicSyntaxGenerationForTransientCmdIdx:PLA
    ; Map a "compressed mode" in the range 0-15 to 0-7 or 128-135.
    CMP #maxMode + 1:BCC ScreenModeInA
    ADC #(shadowModeOffset - (maxMode + 1)) - 1 ; -1 because C is set
.ScreenModeInA
    JMP PrintADecimalNoPadNewline

.Conf5Write
    JSR ConvertIntegerDefaultDecimalChecked
    ; Map a mode 0-7 or 128-135 to a "compressed mode" in the range 0-15.
    CMP #shadowModeOffset:BCC CompressedModeInA
    SBC #shadowModeOffset - (maxMode + 1)
.CompressedModeInA
    JMP SetConfigValueA
}

.ConfTV
{
Tmp = TransientZP + 6

    BCS ConfTVWrite
    JSR GetConfigValue
    ; We have a 4-bit value; bit 0 is the interlace bit, bits 1-3 are a *signed* vertical shift.
    PHA:JSR ConfRefDynamicSyntaxGenerationForTransientCmdIdx:PLA ; SQUASH: worth factoring out?
    PHA ; save value for handling interlace bit below
    ; Get the vertical shift option from bits 1-3 and sign extend it.
    LSR A
    CMP #4:BCC Positive
    ORA #%11111000
.Positive
    JSR PrintADecimalNoPad
    LDA #',':JSR OSWRCH
    PLA:AND #1:JMP PrintADecimalNoPadNewline

.ConfTVWrite
    ; SQUASH: Can't we STA Tmp instead of PHA, then omit the Lda Tmp:PLA?
    JSR ConvertIntegerDefaultDecimalChecked:AND #7:ASL A:PHA
    JSR FindNextCharAfterSpaceSkippingComma:JSR ConvertIntegerDefaultDecimalChecked:AND #1:STA Tmp
    PLA:ORA Tmp:JMP SetConfigValueA
}

; SFTODO: This entire block is dead code
{
.L95BF
    LDA #&00
    ASL L00AE
    ROL A
    ASL L00AE
    ROL A
    RTS

.Dead1
    JSR L95BF
    JSR PrintADecimalNoPad
    LDA #','
    JMP OSWRCH

.Dead2
    ASL L00AE
    ASL L00AE
    JSR FindNextCharAfterSpaceSkippingComma
    JSR ConvertIntegerDefaultDecimalChecked
    AND #&03
    ORA L00AE
    STA L00AE
    RTS
}
			
; Autoboot - Service call &03
; Note that we are expecting to be in bank 15, so nothing else can intercept this call before
; we see it.
.service03
{
    ; Before doing "filing system stuff" which logically relates to this service call, we use
    ; it just as a convenient way to execute the following code at a suitable point during
    ; reset.

    ; If KEYV is set up to use the extended vector mechanism by a ROM which has &47 ('G') at
    ; &800D, set romselMemsel on the extended vector bank number. I am fairly confident the
    ; intention here is to detect GENIE (both 1.01 and 1.02 match that test) having claimed
    ; KEYV during an earlier reset-related service call; by patching its extended vector
    ; bank number to have romselMemsel set, it will have access to video RAM and so will work
    ; correctly even if we're in a shadow mode.
    ;
    ; SFTODO: Ken - just a random thought, GENIE is PALPROM-ish with extra RAM, would your v2
    ; board maybe be able to run it? Some discussion on stardot
    ; https://stardot.org.uk/forums/viewtopic.php?f=7&t=16297
    LDA KEYVH:CMP #&FF:BNE NoGenie
    LDA #&0D:STA osRdRmPtr:LDA #&80:STA osRdRmPtr + 1:LDY XKEYVBank:JSR OSRDRM
    CMP #'G':BNE NoGenie
    LDA XKEYVBank:ORA #romselMemsel:STA XKEYVBank
.NoGenie

    CLC:JSR SFTODOALARMSOMETHING
    BIT L03A4:BPL L9611 ; SFTODO!?
    JMP L964C
.L9611

    ; Handle *BOOT.
    PRVEN
    LDX lastBreakType:CPX #1:BNE NotPowerOnStarBoot
    CLC:LDA prvBootCommandLength:BEQ NotPowerOnStarBoot ; branch if we don't have a *BOOT command
    ; We're going to poke the *BOOT command into the OS function key buffer as *KEY10. See
    ; https://tobylobster.github.io/mos/mos/S-s14.html#SP12 for details on the format of this
    ; buffer.
    ;
    ; Our *BOOT command is A bytes long, so the first free offset from osFunctionKeyStringBase
    ; after our *KEY10 definition will be A+&0F. Set all keys to have this offset as their
    ; start offset to indicate they are undefined; we also write to
    ; osFunctionKeyFirstFreeOffset here to record this space as used.
    ADC #&0F
    ASSERT osFunctionKeyStartOffsets + 16 == osFunctionKeyFirstFreeOffset
    LDX #0
.CopyFirstFreeOffsetLoop
    STA osFunctionKeyStartOffsets,X
    INX:CPX #17:BNE CopyFirstFreeOffsetLoop
    ; Our *KEY10 definition will start at &B01+&10.
    LDA #osFunctionKeyFirstValidOffset:STA osFunctionKeyStartOffsets + 10
    ; Copy the *BOOT command to &B01+&10 onwards.
    LDX #1
.CopyBootStringLoop
    LDA prvBootCommand - 1,X:STA osFunctionKeyStringBase + osFunctionKeyFirstValidOffset - 1,X
    INX:CPX prvBootCommandLength:BNE CopyBootStringLoop
.NotPowerOnStarBoot
    PRVDIS

    ; Now arrange for selection of the desired filing system. If a key is pressed we let the
    ; usual mechanism kick in and don't bring the *CONFIGURE FILE setting into play.
    LDA #osbyteKeyboardScanFrom10:JSR OSBYTE:CPX #keycodeNone:BEQ NoKeyPressed
.L964C
    LDX romselCopy:DEX
    JMP SelectFirstFilingSystemROMLessEqualXAndLanguage
.NoKeyPressed

    ; SFTODO: Why do we have two different "ways" to call SetDfsNfsPriority?
    LDA lastBreakType:BNE NotSoftReset1
    ; It's a soft reset, so reselect the last filing system selected.
    LDX #prvLastFilingSystem - prv83:JSR ReadPrivateRam8300X
    PHA ; SFTODO: Why can't we just do the read from prvLastFilingSystem *after* JSR SetDfsNfsPriority and avoid this PHA/PLA?
    JSR SetDfsNfsPriority ; SFTODO: Note this does *not* use the value in A - I suspect the way the code worked got changed at one point and we're seeing some redundant code left behind
    PLA
    AND #&7F ; SQUASH: probably not useful, see SQUASH: comment on service0F
    TAX
    CPX romselCopy:BCC SelectFirstFilingSystemROMLessEqualXAndLanguage
.NotSoftReset1
    JSR SetDfsNfsPriority
    JMP SelectConfiguredFilingSystemAndLanguage

.SetDfsNfsPriority
    LDX #userRegDiscNetBootData:JSR ReadUserReg
    ROR A:ROR A:AND #&80:TAX
    LDA #osbyteReadWriteStartupOptions:LDY #&7F:JSR OSBYTE ; SQUASH: JMP OSBYTE
    RTS

.SelectConfiguredFilingSystemAndLanguage
    LDX #userRegLangFile:JSR ReadUserReg:AND #&0F:TAX ; get *CONFIGURE FILE value
    ; SFTODO: If the selected filing system is >= our bank, start one bank lower?! This seems odd, although *if* we know we're bank 15, this really just means "start below us" (presumably to avoid infinite recursion)
    CPX romselCopy:BCC SelectFirstFilingSystemROMLessEqualXAndLanguage
    DEX
.SelectFirstFilingSystemROMLessEqualXAndLanguage
    JSR PassServiceCallToROMsLessEqualX
    LDA lastBreakType:BNE NotSoftReset2
    LDA currentLanguageRom:BPL EnterLangA ; SFTODO: Do we expect this to always branch? Not at all sure.
.NotSoftReset2
    LDX #userRegLangFile:JSR ReadUserReg:JSR LsrA4 ; get *CONFIGURE LANG value
    JMP EnterLangA ; SQUASH: BPL ; branch always
			
.NoLanguageEntryAndNoTube
    LDA romselCopy ; enter IBOS as the current language
.EnterLangA
    TAX
    LDA romTypeTable,X:ROL A:BPL NoLanguageEntry
    JMP LDBE6 ;OSBYTE 142 - ENTER LANGUAGE ROM AT &8000 (http://mdfs.net/Docs/Comp/BBC/OS1-20/D940) - we enter one byte early so carry is clear, which might indicate "initialisation" (this based on that mdfs.net page; I can't find anything about this in a quick look at other documentation)

.NoLanguageEntry
    BIT tubePresenceFlag:BPL NoLanguageEntryAndNoTube
    ; Inform tube no language was found at break.
    LDA #0:CLC:JMP L0400

; SFTODO: This has only one caller
.PassServiceCallToROMsLessEqualX
    TXA:PHA
    TSX:LDA L0104,X:TAY ; get Y from the service call SQUASH: Just use LDY L0104,X to load directly?
    PLA:TAX
    LDA romselCopy:PHA
    LDA #3 ; this service call number
    JMP LF16E ; OSBYTE 143 - Pass service commands to sideways ROMs (http://mdfs.net/Docs/Comp/BBC/OS1-20/F135), except we enter partway through to start at bank X not bank 15
}

; Absolute workspace claim - service call &01
;
; We're not going to claim any workspace, but we use this call to take control early in the
; reset process.
.service01
{
tmp = &A8
    ; SQUASH: I think this code is high enough in the IBOS ROM we don't need to be indirecting
    ; via WritePrivateRam8300X and could just set PRV1 and access directly?
    LDA #0:STA ramselCopy:STA ramsel ; shadow off SFTODO?
    LDX #7
    LDA #&FF
.WriteLoop
    JSR WritePrivateRam8300X
    DEX:BNE WriteLoop
    LDA romselCopy:AND #maxBank:ASSERT prvIbosBankNumber == prv83 + 0:JSR WritePrivateRam8300X
    BIT L03A4:BPL L96EE ; SFTODO!?
    JMP ExitServiceCallIndirect
			
.L96EE
    LDX #userRegPrvPrintBufferStart:JSR ReadUserReg
    LDX #prvPrvPrintBufferStart-prv83:JSR WritePrivateRam8300X
    LDX lastBreakType:BEQ SoftReset
    LDX #userRegOsModeShx:JSR ReadUserReg
    PHA
    AND #7:LDX #prvOsMode - prv83:JSR WritePrivateRam8300X
    JSR assignDefaultPseudoRamBanks
    PLA
    AND #8:BEQ ShxInA
    LDA #prvOn
.ShxInA
    LDX #prvShx - prv83:JSR WritePrivateRam8300X
.SoftReset
    JSR IbosSetUp

    ; Implement the *CONFIGURE TV setting.
    LDX #userRegModeShadowTV:JSR ReadUserReg
    ; Arithmetic shift A right 5 bits to get a sign-extended version of the vertical shift
    ; setting in A.
    ; SQUASH: Could we optimise this using technique from http://wiki.nesdev.com/w/index.php/6502_assembly_optimisations#Arithmetic_shift_right?
    PHA
    ROL A:PHP:ROR A ; save sign bit on stack
    LDX #5
.ShiftLoop
    PLP:PHP ; peek sign bit from stack
    ROR A
    DEX:BNE ShiftLoop
    PLP
    TAX
    PLA:AND #&10:BEQ InterlaceInA
    LDA #1
.InterlaceInA
    TAY
    LDA #osbyteTV:JSR OSBYTE

    ; Set the screen mode. On a soft reset we preserve the last selected mode (like the
    ; Master), unless we're in OSMODE 0; on other resets we select the *CONFIGUREd mode.
    LDA #vduSetMode:JSR OSWRCH
    LDX lastBreakType:BNE DontPreserveScreenMode ; branch if not soft reset
    LDX #prvOsMode - prv83:JSR ReadPrivateRam8300X:BEQ DontPreserveScreenMode
    LDX #prvLastScreenMode - prv83:JSR ReadPrivateRam8300X:JSR OSWRCH
    JMP ScreenModeSet
.DontPreserveScreenMode
    LDX #userRegModeShadowTV:JSR ReadUserReg:AND #&0F
    ; Map the "compressed mode" in the range 0-15 to 0-7 or 128-135.
    ; SQUASH: We have at least two copies of this, worth sharing?
    CMP #maxMode + 1:BCC ScreenModeInA
    ADC #(shadowModeOffset - (maxMode + 1)) - 1 ; -1 because C is set
.ScreenModeInA
    JSR OSWRCH
.ScreenModeSet

    JSR DisplayBannerIfRequired

    LDX #userRegKeyboardDelay:JSR ReadUserReg:TAX:LDA #osbyteSetAutoRepeatDelay:JSR OSBYTE
    LDX #userRegKeyboardRepeat:JSR ReadUserReg:TAX:LDA #osbyteSetAutoRepeatPeriod:JSR OSBYTE
    LDX #userRegPrinterIgnore:JSR ReadUserReg:TAX:LDA #osbyteSetPrinterIgnore:JSR OSBYTE

    LDX #userRegTubeBaudPrinter:JSR ReadUserReg:JSR LsrA2:PHA
    AND #&07:CLC:ADC #1 ; mask off baud rate bits and add 1 to convert to 1-8 range
    PHA:TAX:LDA #osbyteSetSerialReceiveRate:JSR OSBYTE
    PLA:TAX:LDA #osbyteSetSerialTransmitRate:JSR OSBYTE
    PLA:JSR LsrA3:TAX:LDA #osbyteSetPrinterType:JSR OSBYTE

    LDX #userRegFdriveCaps:JSR ReadUserReg:PHA

    ; Implement *CONFIGURE xCAPS.
                   AND #%00111000             ; get *CONFIGURE CAPS bits
    LDX #%10100000:CMP #%00001000:BEQ CapsInX ; *CONFIGURE SHCAPS?
    LDX #%00110000:CMP #%00010000:BEQ CapsInX ; *CONFIGURE NOCAPS?
    LDX #%00100000                            ; *CONFIGURE CAPS
.CapsInX
    LDY #0:LDA #osbyteReadWriteKeyboardStatus:JSR OSBYTE

    ; Implement *CONFIGURE FDRIVE and *CONFIGURE BOOT.
    ; There are 3 bits allocated to FDRIVE, but *FX255 only has two bits for drive speed. The
    ; most significant FDRIVE bit will be shifted up into bit 6 of tmp here, but it will be
    ; masked off at BootInAMaskInY.
    PLA:AND #%00000111 ; get *CONFIGURE FDRIVE bits from userRegFdriveCaps
    ASL A:ASL A:ASL A:ASL A:STA tmp
    LDX #userRegDiscNetBootData:JSR ReadUserReg:PHA
    LDY #%11001000 ; preserve b7, b6 and b3 (boot flag) on soft reset
    LDA lastBreakType:BEQ BootInAMaskInY ; branch if soft reset
    ; Get the boot flag from userRegDiscNetBootData into b3 of A
    PLA:PHA ; peek userRegDiscNetBootData value
    ; SFTODO: So where do we set b7 to select NFS or DFS priority? I wonder if this has been
    ; bodged in slightly and could be more efficiently handled here, but perhaps there's a good
    ; reason for doing it elsewhere.
    ; On non-soft reset we preserve b6-7 of existing startup options, which presumably come
    ; from the keyboard links (SFTODO: or whatever code adjusts b7 to select NFS or DFS priority).
    ; ENHANCE: Would it be worth allowing IBOS to control b6 and b7?
    LDY #%11000000
    LSR A ; boot flag is bit 4 of userRegDiscNetBootData, we need it in bit 3
    AND #%00001000
    EOR #%00001000 ; userRegDiscNetBootData uses opposite sense to *FX255
.BootInAMaskInY
    ORA tmp
    ORA #%00000111 ; force mode 7 SFTODO: seems a bit pointless but harmless, I guess
    AND #%00111111
    TAX:LDA #osbyteReadWriteStartupOptions:JSR OSBYTE ; set to (<old value> AND Y) EOR X

    ; Set the serial data format (word length, parity, stop bits) directly on the ACIA (control
    ; register bits CR2, CR3 and CR4).
    PLA:JSR LsrA3:AND #%00011100 ; A=userRegDiscNetBootData data bits shifted into b2-4
    TAX:          LDY #%11100011:LDA #osbyteReadWriteAciaRegister:JSR OSBYTE

.ExitServiceCallIndirect
    JMP ExitServiceCall
}

; SQUASH: LsrA4 has only one caller (but there are places where it should be used and isn't).
.LsrA4
    LSR A
; SQUASH: Use of JSR LsrA3 or JSR LsrA2 is silly - the former is neutral on space and slower,
; the latter is both larger and slower.
.LsrA3
    LSR A
.LsrA2
    LSR A
    LSR A
    RTS

; Tube system initialisation - service call &FF
; SFTODO: Not at all clear what's going on here
.serviceFF
{
    XASSERT_USE_PRV1
    JSR clearShenPrvEn:PHA
    BIT prvSFTODOTUBEISH:BMI L9836
    LDA lastBreakType:BEQ SoftReset
    BIT L03A4 ; SFTODO!?
    BMI L983D
    LDX #userRegTubeBaudPrinter:JSR ReadUserReg:AND #1:BNE WantTube ; branch if *CONFIGURE TUBE
    LDA #&FF
.WantTube
    STA prvSFTODOTUBE2ISH
.SoftReset
    BIT prvSFTODOTUBE2ISH:BPL L983D
.L9836
    PLA:JSR PRVDISStaRamsel
    JMP ExitServiceCall
.L983D
    PLA:JSR PRVDISStaRamsel
    PLA:TAY ; restore original Y on entry to service call
    PLA ; discard stacked original X
    PLA ; discard stacked original A
    LDA #&FF
    LDX #&00
    JMP LDC16 ; STX romselCopy:STX romsel:RTS, i.e. page in bank 0 (SFTODO!?) and return from service call

; SQUASH: This only has one caller
.clearShenPrvEn ; SFTODO: not super happy with this name
    LDA ramselCopy:PHA
    LDA #0:STA ramselCopy:STA ramsel
    PRVEN
    PLA
    RTS

.PRVDISStaRamsel
    PHA
    PRVDIS
    PLA
    STA ramselCopy
    STA ramsel
    RTS
}

; Vectors claimed - Service call &0F
;
; If the current filing system is DFS or NFS, set prvLastFilingSystem = (prvLastFilingSystem AND &80)
; OR (filing system bank AND &0F). Otherwise, set prvLastFilingSystem = filing system bank.
;
; SQUASH: I think there is some semi-dead code here related to DFS/NFS priority. The only place
; prvLastFilingSystem is used is in service03, which has some slightly odd code and masks off
; bit 7 of prvLastFilingSystem value before using it. I think it's therefore pointless to
; maintain that bit, and this code should probably just do prvLastFilingSystem = XFILEVBank, or
; possibly prvLastFilingSystem = XFILEVBank AND maxBank, since DNFS *may* be using bit 7 of its
; bank number as a DFS/NFS flag and we don't want that breaking things in service03. (service03
; currently does AND &7F; we don't need both that *and* AND maxBank here.)
; SFTODO: Ken - *if* it's easy at some point, could you please try "PRINT ?&DBC" on a BBC B
; with DNFS (i.e. DFS 1.20 and NFS whatever-it-is) and *NET as the current filing system? If
; it's not easy don't worry, it's not urgent and I may be able to find the answer somewhere
; online.
.service0F
{
    LDX #prvLastFilingSystem - prv83:JSR ReadPrivateRam8300X:AND #&80:PHA
    LDA #osargsReadFilingSystemNumber:LDX #TransientZP:LDY #0:JSR OSARGS ; SQUASH: don't set X?
    TSX ; SQUASH: redundant?
    ; SQUASH: The LDY operations here are redundant, aren't they? ExitServiceCall will restore Y.
    LDY #0:CMP #FilingSystemNfs:BEQ L988D
    LDY #&80:CMP #FilingSystemDfs:BEQ L988D
    LDA XFILEVBank:JMP L9896
.L988D
    LDA XFILEVBank:AND #maxBank ; SFTODO: is the AND particularly significant here? We don't do it on the other branch
    TSX:ORA L0101,X ; access stacked prvLastFilingSystem value
.L9896
    LDX #prvLastFilingSystem - prv83:JSR WritePrivateRam8300X
    PLA ; discard stacked prvLastFilingSystem value
    JMP ExitServiceCall
}

; SQUASH: This has only one caller
; ENHANCE: At least in b-em, I note that with a second processor, we get the INTEGRA-B banner
; *as well as* the tube banner. This doesn't happen with the standard OS banner. Arguably this
; is desirable, but we *could* potentially not show our own banner if we have a second
; processor attached to be more "standard".
; ENHANCE: Perhaps a bit of a novelty, but could we make the startup banner *CONFIGURE-able? If
; we parsed it using GSINIT/GSINIT it would potentially open up the prospect of things like the
; "mode 7 owl" as well as/instead of simple text.
; ENHANCE: It's a bit "marketing", but we could add 32K to the displayed RAM size to account for
; the shadow/private RAM. This would be gratuitously incompatible with IBOS 1.20 though.
.DisplayBannerIfRequired
{
RamPresenceFlags = TransientZP

    ; We just use the default banner if we're in OSMODE 0. SQUASH: CMP #0 is redundant
    LDX #prvOsMode - prv83:JSR ReadPrivateRam8300X:CMP #0:BEQ Rts

    ; If we're in the "ignore OS startup message" state (b7 clear), do nothing. I suspect this
    ; occurs if an earlier ROM has managed to get in before us and probably can't occur in
    ; practice if we're in bank 15.
    LDA #osbyteReadWriteEnableDisableStartupMessage:LDX #0:LDY #&FF:JSR OSBYTE:TXA:BPL Rts

    ; Set the "ignore OS startup message" state ourselves. We will also clear bit 0
    ; unconditionally rather than preserving it, but in practice this probably doesn't matter
    ; (it controls locking up the machine on certain types of !BOOT error).
    LDA #osbyteReadWriteEnableDisableStartupMessage:LDX #0:LDY #0:JSR OSBYTE

    ; Print "Computech".
    LDX #computechStart - romHeader
.BannerLoop1
    LDA romHeader,X:JSR OSWRCH
    INX:CPX #(computechEnd + 1) - romHeader:BNE BannerLoop1

    ; Print " INTEGRA-B".
    LDX #(ReverseBannerEnd - 1) - ReverseBanner
.BannerLoop2
    LDA ReverseBanner,X:JSR OSWRCH
    DEX:BPL BannerLoop2

    LDA lastBreakType:BEQ SoftReset ; soft reset message is simpler and quieter

    LDA #vduBell:JSR OSWRCH

    ; Count sideways RAM banks in kilobytes and print the result.
    LDX #userRegRamPresenceFlags:JSR ReadUserReg:STA RamPresenceFlags
    LDX #7
    LDA #0
.CountLoop
    LSR RamPresenceFlags:BCC NotPresent ; branch if no RAM in this bank
    ADC #32 - 1 ; add 32K, -1 because carry is set
.NotPresent
    DEX:BPL CountLoop
    ; If we have 256K of RAM A will have wrapped to 0; we can't have 0K of sideways RAM so
    ; there's no ambiguity.
    CMP #0:BEQ AllBanksPresent ; SQUASH: use TAX instead of CMP #0
    SEC:JSR PrintADecimal ; SQUASH: JSR PrintADecimalNoPad
    JMP PrintKAndNewline
.AllBanksPresent
    LDA #'2':JSR OSWRCH
    LDA #'5':JSR OSWRCH
    LDA #'6':JSR OSWRCH
.PrintKAndNewline
    LDA #'K':JSR OSWRCH
.SoftReset
    JSR OSNEWL
    BIT tubePresenceFlag:BMI Rts ; branch if tube present
    JMP OSNEWL
    ; SQUASH: Control can't flow through to here, can we move the Rts label to a nearby Rts to
    ; save a byte?
.Rts
    RTS

.ReverseBanner
    EQUS " B-ARGETNI" ; "INTEGRA-B " reversed
.ReverseBannerEnd
}

; SFTODO: There are a few cases where we JMP to osbyteXXInternal, if we rearranged the code a little (could always use macros to maintain readability, if that's a factor) we could probably save some JMPs
; OSBYTE &44 (68) - Test RAM presence
; The Master Reference Manual (part 1) defines this in terms of banks 4-7, but we implement it
; in terms of pseudo banks W-Z.
.osbyte44Internal
{
    PRVEN
    PHP:SEI
    LDA #0:STA oswdbtX
    LDY #3 ; SFTODO: mildly magic, (max) number of pseudo banks - 1
.BankLoop
    STY prvTmp
    ; SQUASH: Use LDX abs,Y and save TAX?
    LDA prvPseudoBankNumbers,Y:BMI NotRam ; this pseudo-bank is not defined
    TAX:JSR TestRamUsingVariableMainRamSubroutine:BNE NotRam
    ; We only count a bank as RAM if it's not in use to hold a sideways ROM.
    LDA prvRomTypeTableCopy,X
    BEQ Ram
    CMP #2:BEQ Ram ; SFTODO: mildly magic, this is the *SRDATA value I think
.NotRam
    CLC:BCC NextBank; always branch
.Ram
    SEC
.NextBank
    ROL oswdbtX
    LDY prvTmp:DEY:STY prvTmp:BPL BankLoop
    JMP plpPrvDisexitSc ; SQUASH: BMI always branch?
}

;OSBYTE &45 (69) - Test PSEUDO/Absolute usage (http://beebwiki.mdfs.net/OSBYTE_%2645)
.osbyte45Internal
{
            PRVEN								;switch in private RAM
            PHP
            SEI
            LDA #&00
            STA oswdbtX
	  ; SFTODO: Is all the saving and restoring of Y needed? FindAInPrvSFTODOFOURBANKS doesn't seem to corrupt Y.
            LDY #&03
.bankLoop   STY prvTmp
            LDA prvPseudoBankNumbers,Y
            BMI bankAbs   								;&FF indicates no absolute bank assigned to this pseudo-bank SFTODO: I guess we say that's an absolute addressing bank as it is less likely our caller will decide to try to use it, but it is a bit arbitrary
            JSR FindAInPrvSFTODOFOURBANKS ; SFTODO: I am inferring SFTODOFOURBANKS is therefore a list of up to 4 banks being used for pseudo-addressing - the fact we need to do the previous BMI suggests the list is padded to the full 4 entries with &FF
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
    PRVEN
    LDX #0
.BankLoop
    ROR transientRomBankMask + 1:ROR transientRomBankMask:BCC SkipBank
    JSR WipeBankAIfRam
.SkipBank
    INX:CPX #maxBank + 1:BNE BankLoop
    JMP PrvDisexitSc

; SQUASH: This has only one caller, the code immediately above - could it just be inlined?
.WipeBankAIfRam
    JSR TestRamUsingVariableMainRamSubroutine:BNE Rts
    PHA
    LDX #lo(wipeRamTemplate):LDY #hi(wipeRamTemplate):JSR CopyYxToVariableMainRamSubroutine
    PLA
    JSR variableMainRamSubroutine
    PHA:JSR removeBankAFromSFTODOFOURBANKS:PLA ; SFTODO: So *SRWIPE implicitly performs a *SRROM on each bank it wipes?
    TAX:LDA #0:STA romTypeTable,X:STA prvRomTypeTableCopy,X
.Rts
    RTS
}

; SQUASH: Dead data
{
    EQUS "RAM","ROM"
}

; SQUASH: This has only one caller
; A=0 on entry means the header should say "RAM", otherwise it will say "ROM". A is also copied into the (unused) second byte of the bank's service entry; SFTODO: I don't know why specifically, but maybe this is just done because that's what the Acorn DFS SRAM utilities do (speculation; I haven't checked).
.WriteRomHeaderAndPatchUsingVariableMainRamSubroutine
{
    XASSERT_USE_PRV1
    PHA
    LDX #lo(WriteRomHeaderTemplate):LDY #hi(WriteRomHeaderTemplate)
    JSR CopyYxToVariableMainRamSubroutine
    PLA:BEQ Ram
    ; ROM - so patch variableMainRamSubroutine's ROM header to say "ROM" instead of "RAM"
    LDA #'O'
    STA variableMainRamSubroutine + (WriteRomHeaderTemplateDataAO - WriteRomHeaderTemplate)
.Ram
    LDA prvOswordBlockCopy + 1 ; SFTODO: THIS IS THE SAME LOCATINO AS IN SRROM/SRDATA SO WE NEED A GLOBAL NAME FOR IT RATHER THAN JUST THE LOCAL ONE WE CURRENTLY HAVE (bankTmp)
    JSR checkRamBankAndMakeAbsolute
    STA prvOswordBlockCopy + 1
    STA variableMainRamSubroutine + (WriteRomHeaderTemplateSFTODO - WriteRomHeaderTemplate)
    JMP variableMainRamSubroutine
}

{
; Search prvSFTODOFOURBANKS for A; if found, remove it, shuffling the elements down so all the non-&FF entries are at the start and are followed by enough &FF entries to fill the list.
.^removeBankAFromSFTODOFOURBANKS
    XASSERT_USE_PRV1
    LDX #3 ; SFTODO: MILDLY MAGIC
.FindLoop
    CMP prvSFTODOFOURBANKS,X:BEQ Found
    DEX:BPL FindLoop
    SEC ; SFTODO: Not sure any callers care about this, and I think we'll *always* exit with carry set even if we do find a match
    RTS

.Found
    LDA #&FF:STA prvSFTODOFOURBANKS,X
.Shuffle
    LDX #0:LDY #0
.ShuffleLoop
    LDA prvSFTODOFOURBANKS,X:BMI Unassigned
    STA prvSFTODOFOURBANKS,Y:INY
.Unassigned
    INX:CPX #&04:BNE ShuffleLoop ; SFTODO: mildly magic
    TYA:TAX
    JMP PadLoopStart ; SQUASH: BPL always?
			
.PadLoop
    LDA #&FF:STA prvSFTODOFOURBANKS,Y
    INY
.PadLoopStart
    CPY #4:BNE PadLoop  ; SFTODO: mildly magic
    RTS

; If there's an unused entry, add A to SFTODOFOURBANKS and return with C clear, otherwise
; return with C set to indicate no room.
; SQUASH: This has only one caller
.^AddBankAToSFTODOFOURBANKS
    XASSERT_USE_PRV1
    PHA:JSR Shuffle:PLA
    CPX #4:BCS Rts ; SFTODO: mildly magic
    STA prvSFTODOFOURBANKS,X
.Rts
    RTS
}

; Return with X such that prvSFTODOFOURBANKS[X] == A (N flag clear), or with X=-1 if there is no such X (N flag set).
; SQUASH: This only has one caller
.FindAInPrvSFTODOFOURBANKS
{
    XASSERT_USE_PRV1
    LDX #3 ; SFTODO: mildly magic
.Loop
    CMP prvSFTODOFOURBANKS,X:BEQ Rts
    DEX:BPL Loop
.Rts
    RTS
}

;*SRSET Command
{
.^srset     LDA (transientCmdPtr),Y
            CMP #'?'
            BEQ showStatus
	  ; Select the first four suitable banks from the list provided and store them at prvPseudoBankNumbers.
            JSR parseRomBankList
            PRVEN
            LDX #&00
            LDY #&00
.bankLoop   ROR transientRomBankMask + 1
            ROR transientRomBankMask
            BCC SkipBank
            TYA
            PHA
            JSR TestRamUsingVariableMainRamSubroutine
            BNE plyAndSkipBank ; branch if not RAM
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
            BCS SkipBank
            TXA
            STA prvPseudoBankNumbers,Y
            INY
            CPY #&04
            BCS done
.SkipBank   INX
            CPX #maxBank + 1
            BNE bankLoop
	  ; There aren't four entries in prvPseudoBankNumbers (if there were we'd have taken the "BCS done" branch above), so pad the list with &FF entries.
            LDA #&FF
.PadLoop    STA prvPseudoBankNumbers,Y
            INY
            CPY #&04
            BCC PadLoop
.done       JMP PrvDisexitSc

.showStatus
            CLC
            PRVEN								;switch in private RAM
            LDY #&00
.ShowLoop   CLC
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
            JSR PrintADecimal								;Convert binary number to numeric characters and write characters to screen
.bankShown  CPY #&03								;Check for 4th bank
            BEQ osnewlPrvDisexitSc							;Yes? Then end
            LDA #','
            JSR OSWRCH								;Write to screen
            JSR printSpace								;write ' ' to screen
            INY									;Next
            BNE ShowLoop								;Loop for 'X', 'Y' & 'Z'
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
            PRVEN								;switch in private RAM
            LDX #&00
.bankLoop   ROR transientRomBankMask + 1
            ROR transientRomBankMask
            BCC SkipBank
            PLP
            PHP
            JSR doBankX
.SkipBank   INX
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
            JSR TestRamUsingVariableMainRamSubroutine
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
            JSR AddBankAToSFTODOFOURBANKS
            BCS failSFTODOB ; SFTODO: branch if we already had four banks and so couldn't add this one
.isSrrom    LDA romRamFlagTmp
            JSR WriteRomHeaderAndPatchUsingVariableMainRamSubroutine
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
    XASSERT_USE_PRV1
            AND #&7F								;drop the highest bit
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
            LDX #&00
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
    XASSERT_USE_PRV1
            LDA prvOswordBlockCopy + 1
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
    XASSERT_USE_PRV1
            LDA prvOswordBlockCopy + 7						;ROM number
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
    XASSERT_USE_PRV1
            JSR parseBankNumber
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
    XASSERT_USE_PRV1
            LDA #&00
            STA prvOswordBlockCopy + 6							;low byte of buffer length
            STA prvOswordBlockCopy + 7							;high byte of buffer length
.L9BF1      JSR FindNextCharAfterSpace							;find next character. offset stored in Y
            LDA (transientCmdPtr),Y
            CMP #vduCr
            BEQ rts  								;Yes? Then jump to end
            AND #CapitaliseMask								;Capitalise
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
    XASSERT_USE_PRV1
            CLC
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
	  JMP GenerateSyntaxErrorForTransientCommandIndex

.L9C42
    XASSERT_USE_PRV1
      JSR ConvertIntegerDefaultHex
            BCS GenerateSyntaxErrorIndirect
            LDA L00B0
            STA prvOswordBlockCopy + 8
            LDA L00B1
            STA prvOswordBlockCopy + 9
            RTS

{
.^L9C52
    XASSERT_USE_PRV1
      JSR FindNextCharAfterSpace								;find next character. offset stored in Y
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
    XASSERT_USE_PRV1
            JSR ConvertIntegerDefaultHex
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
    XASSERT_USE_PRV1
            JSR FindNextCharAfterSpace								;find next character. offset stored in Y
            LDA (transientCmdPtr),Y
            CMP #'+'
            PHP
            BNE L9CA7
            INY
.L9CA7      JSR ConvertIntegerDefaultHex
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
.^srread	  PRVEN								;switch in private RAM
            LDA #&00
            JMP L9CDF
			
;*SRWRITE Command
.^srwrite	  PRVEN								;switch in private RAM
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
            LDA L00AD
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
            SEC
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
    XASSERT_USE_PRV1
            BIT prvOswordBlockCopy                                                                  ;get function
            BVC secSevRts                                                                           ;branch if we have an absolute address
            ; We're dealing with a pseudo-address.
            BIT L00A9
            BVC ClcRts
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
.ClcRts
.L9D84      CLC
            RTS

.secSevRts
.BadDate3
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
    XASSERT_USE_PRV1
            JSR adjustTransferParameters
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
            JSR RaiseError								;Goto error handling, where calling address is pulled from stack
	  EQUB &80
	  EQUS "Bad address", &00

.errorNotAllocated
.L9DCA      JSR RaiseError								;Goto error handling, where calling address is pulled from stack
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
    XASSERT_USE_PRV1
            LDY prvOswordBlockCopy + 8 ; get low byte of sideways address
            LDA prvOswordBlockCopy + 9 ; get high byte of sideways address
            BIT prvOswordBlockCopy ; test function
            BVC absoluteAddress
            JSR convertPseudoAddressToAbsolute
            STX prvOswordBlockCopy + 1
.absoluteAddress
            STY transientOs4243SwrAddr
            STA transientOs4243SwrAddr + 1
.^getBufferAddressAndLengthFromPrvOswordBlockCopy
    XASSERT_USE_PRV1
            LDA prvOswordBlockCopy + 2 ; get low byte of main memory address (OSWORD &42) or buffer address (OSWORD &43)
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
.TestRamTemplate
{
      	  LDX romselCopy										;Read current ROM number from &F4 and store in X
            STA romselCopy										;Write new ROM number from A to &F4
            STA romsel									;Write new ROM number from A to &FE30
            LDA romBinaryVersion									;Read contents of &8008
            EOR #&FF									;and XOR with &FF 
            STA romBinaryVersion									;Write XORd data back to &8008
            JSR variableMainRamSubroutine+L9E37-TestRamTemplate								;Delay 1 before read back
            JSR variableMainRamSubroutine+L9E37-TestRamTemplate								;Delay 2 before read back
            JSR variableMainRamSubroutine+L9E37-TestRamTemplate								;Delay 3 before read back
            JSR variableMainRamSubroutine+L9E37-TestRamTemplate								;Delay 4 before read back
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
            ASSERT P% - TestRamTemplate <= variableMainRamSubroutineMaxSize
}

;Wipe RAM at bank A
;this code is relocated to and executed at &03A7
.wipeRamTemplate
{
      	  LDX romselCopy
            STA romselCopy
            STA romsel
            LDA #&00
.L9E41      STA prv80+&00 ; SFTODO: Change to &8000? I think this is wiping arbitrary banks, not particular private RAM.
            INC variableMainRamSubroutine+L9E41-wipeRamTemplate+1								;Self modifying code - increment LSB of STA in line above
            BNE L9E41									;Test for overflow
            INC variableMainRamSubroutine+L9E41-wipeRamTemplate+2								;Increment MSB of STA in line above
            BIT variableMainRamSubroutine+L9E41-wipeRamTemplate+2								;test MSB bit 6 (have we reached &4000?)
            BVC L9E41									;No? Then loop
            LDA romselCopy
            STX romselCopy
            STX romsel
            RTS
            ASSERT P% - wipeRamTemplate <= variableMainRamSubroutineMaxSize
}

;write ROM header to RAM at bank A
;this code is relocated to and executed at &03A7
.WriteRomHeaderTemplate
{
      	  LDX romselCopy
            STA romselCopy
            STA romsel
            LDY #&0F
.L9E62      LDA variableMainRamSubroutine + srDataHeader - WriteRomHeaderTemplate,Y
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
.^WriteRomHeaderTemplateSFTODO ; SFTODO: Why do we modify this byte of the header?
            EQUB     &00,&00
	  EQUB &60,&00,&00
	  EQUB romTypeSrData ; SFTODO: This constant is arguably misnamed since we use it for *SRROM banks too (I think)
	  EQUB &0C
	  EQUB &FF
	  EQUS "R"
.^WriteRomHeaderTemplateDataAO
            EQUS "AM", &00
	  EQUS "(C)"
            ASSERT P% - WriteRomHeaderTemplate <= variableMainRamSubroutineMaxSize
}

;save ROM / RAM at bank X to file system
;this code is relocated to and executed at &03A7
.saveSwrTemplate
{
      	  TXA
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
       	  TXA
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
      	  TXA									;&03A7
            LDX romselCopy									;&03A8
            STA romselCopy									;&03AA
            STA romsel								;&03AC
            CPY #&00								;&03AF
            BEQ mainRamTransferTemplateLdaStaPair2
.^mainRamTransferTemplateLdaStaPair1
            LDA (transientOs4243SwrAddr),Y								;&03B3 - Note this is changed to &AA by code at &9FA4
            STA (transientOs4243MainAddr),Y								;&03B5 - Note this is changed to &A8 by code at &9FA4
            DEY									;&03B7
            BNE mainRamTransferTemplateLdaStaPair1

.^mainRamTransferTemplateLdaStaPair2
            LDA (transientOs4243SwrAddr),Y								;&03BA - Note this is changed to &AA by code at &9FA4
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
       	  TXA
            LDX romselCopy
            STA romselCopy
            STA romsel
            INY
            STY variableMainRamSubroutine + (tubeTransferTemplateTransferSize - tubeTransferTemplate)
            LDY #&00
.^tubeTransferTemplateReadSwr
.L9F07      BIT tubeReg3Status
            BVC L9F07
            LDA (transientOs4243SwrAddr),Y
            STA tubeReg3Data
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
            BIT tubeReg3Status
            BPL tubeTransferTemplateWriteSwr
            LDA tubeReg3Data
            STA (transientOs4243SwrAddr),Y
            ASSERT P% - tubeTransferTemplateWriteSwr == tubeTransferTemplateReadSwrEnd - tubeTransferTemplateReadSwr
}

; Copy a short piece of code from YX to variableMainRamSubroutine. This is used to allow code
; which needs to be modified at runtime and/or which needs to page in a different sideways ROM
; bank to be executed.
; SFTODO: Do we have to preserve AC/AD here? It obviously depends on how we're called, but this is transient command space and we're allowed to corrupt it if we're implementing a * command.
.CopyYxToVariableMainRamSubroutine
{
Ptr = &AC ; 2 bytes

    LDA Ptr + 1:PHA:LDA Ptr:PHA
    STX Ptr:STY Ptr + 1
    LDY #variableMainRamSubroutineMaxSize - 1
.CopyLoop
    LDA (Ptr),Y:STA variableMainRamSubroutine,Y
    DEY:BPL CopyLoop
    PLA:STA Ptr:PLA:STA Ptr + 1
    RTS
}

; Prepare for a data transfer between main and sideways RAM, handling case where
; "main" RAM is in parasite, and leave a suitable transfer subroutine at
; variableMainRamSubroutine.
.PrepareMainSidewaysRamTransfer
; SFTODO: I am assuming prvOswordBlockCopy has always been through adjustPrvOsword42Block when this code is called
{
Function = prvOswordBlockCopy ; SFTODO: global constant for this?

    XASSERT_USE_PRV1
    ; Test high bit of 32-bit main memory address to determine if we need to use a tube
    ; transfer. SFTODO: Isn't this technically incorrect? We should be checking for high word
    ; &FFFF, shouldn't we?
    BIT prvOswordBlockCopy + 5:BMI NotTubeTransfer
    BIT tubePresenceFlag:BPL NotTubeTransfer ; branch if no tube present
    LDA #&FF:STA prvTubeReleasePending
.TubeClaimLoop
    LDA #tubeEntryClaim + tubeClaimId:JSR tubeEntry:BCC TubeClaimLoop
    ; Get the 32-bit address from prvOswordBlockCopy and set it up as tube transfer address.
    ; SQUASH: Could we rewrite this using a loop?
    LDA prvOswordBlockCopy + 2:STA L0100
    LDA prvOswordBlockCopy + 3:STA L0101
    LDA prvOswordBlockCopy + 4:STA L0102
    LDA prvOswordBlockCopy + 5:STA L0103
    ; Set b0 of A to be !b7 of Function, with all other bits of A clear.
    ; A=0 means multi-byte transfer, parasite to host
    ; A=1 means multi-byte transfer, host to parasite
    ; So this converts the function into the correct transfer type.
    ; SFTODO: We're ignoring b6 of Function - is that safe? Do we just not support
    ; pseudo-addresses? I don't think this is the same as the pseudo to absolute bank
    ; conversion done inside checkRamBankAndMakeAbsolute - that converts W=10->4 (for example),
    ; I *think* pseudo-addresses make the 64K of SWR look like a flat memory space. I could be
    ; wrong, I can't find any documentation on this right now.
    LDA Function:EOR #&80:ROL A:LDA #0:ROL A
    LDX #lo(L0100):LDY #hi(L0100):JSR tubeEntry
    LDX #lo(tubeTransferTemplate):LDY #hi(tubeTransferTemplate)
    JSR CopyYxToVariableMainRamSubroutine
    BIT Function:BPL Rts ; branch if this is a read from sideways RAM
    ; Patch the tubeTransfer code at variableMainRamSubroutine for writing to sideways RAM
    ; instead of reading.
    LDY #tubeTransferTemplateReadSwrEnd - tubeTransferTemplateReadSwr - 1
.PatchLoop
    LDA tubeTransferTemplateWriteSwr,Y
    STA variableMainRamSubroutine + (tubeTransferTemplateReadSwr - tubeTransferTemplate),Y
    DEY:BPL PatchLoop
.Rts
    RTS

.NotTubeTransfer
    LDA #0:STA prvTubeReleasePending
    LDX #lo(mainRamTransferTemplate):LDY #hi(mainRamTransferTemplate)
    JSR CopyYxToVariableMainRamSubroutine
    BIT Function:BPL Rts2 ; branch if this is a read from sideways RAM
    ; Patch the code at variableMainRamSubroutine to swap the operands of LDA and STA, thereby
    ; swapping the transfer direction.
    LDA #transientOs4243MainAddr
    STA variableMainRamSubroutine + (mainRamTransferTemplateLdaStaPair1 + 1 - mainRamTransferTemplate)
    STA variableMainRamSubroutine + (mainRamTransferTemplateLdaStaPair2 + 1 - mainRamTransferTemplate)
    LDA #transientOs4243SwrAddr
    STA variableMainRamSubroutine + (mainRamTransferTemplateLdaStaPair1 + 3 - mainRamTransferTemplate)
    STA variableMainRamSubroutine + (mainRamTransferTemplateLdaStaPair2 + 3 - mainRamTransferTemplate)
.Rts2
    RTS
}

;Relocation code then check for RAM banks.
; SFTODO: "Using..." part of name is perhaps OTT, but it might be important to "remind" us that this tramples over variableMainRamSubroutine - perhaps change later once more code is labelled up
.TestRamUsingVariableMainRamSubroutine
{
            TXA
            PHA
            LDX #lo(TestRamTemplate)
            LDY #hi(TestRamTemplate)
            JSR CopyYxToVariableMainRamSubroutine								;relocate &32 bytes of code from &9E0A to &03A7
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
            PRVEN								;switch in private RAM
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
			
; SFTODO: Could we move PRVEN to L9FF8 before the STA and save three bytes by not duplicating it for srsave and srload? Note that PrvEn preserves A.
{
; SFTODO: *SRSAVE seems quite badly broken, I think because of problems with
; OSWORD &43.
; "*SRSAVE FOO A000 C000 4 Q" generates "Bad address" and saves nothing.
; "*SRSAVE FOO A000 C000 4" does seem to create the file correctly but then
; generates a "Bad address" error.
; SFTODO: Ken has pointed out those commands are (using Integra-B *SRSAVE conventions) trying to save one byte past the end of sideways RAM, hence "Bad address". I don't know if we should consider changing this to be more Acorn DFS SRAM utils-like in a new version of IBOS or not, but those actual commands do work fine if the end address is fixed. (We could potentially quibble about whether it's right that one of those error-generating command creates an empty file and the other doesn't, but I don't think this is a big deal, and I have no idea what Acorn DFS does either.)
;*SRSAVE Command
.^srsave	  PRVEN								;switch in private RAM
            LDA #&00								;function "save absolute"
            JMP L9FF8
			
;*SRLOAD Command
.^srload	  PRVEN								;switch in private RAM
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
            ; Although OSWORD &43 doesn't use 32-bit addresses, we want to be able to use PrepareMainSidewaysRamTransfer to implement OSWORD &43 and that does respect the full 32-bit address, so we need to patch the OSWORD block to indicate the I/O processor for the sideways address.
.^LA02D
    XASSERT_USE_PRV1
      LDA #&FF
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
            BNE GenerateNotFoundErrorIndirect
	  ; SFTODO: And following on from above, these stores to block+10/11 do suggest it really is meant to the be the data length
            LDA osfileBlock + osfileReadInformationLengthOffset
            STA prvOswordBlockCopy + 10                                                   ;low byte of data length
            LDA osfileBlock + osfileReadInformationLengthOffset + 1
            STA prvOswordBlockCopy + 11                                                   ;high byte of data length
.readFromSwr
            RTS
}

.GenerateNotFoundErrorIndirect
    JMP GenerateNotFoundError

; Open file pointed to by prvOswordBlockCopy in OSFIND mode A, generating a "Not Found" error if it fails.
; After a successful call file handle is stored at L02EE.
; SFTODO: Perhaps rename openOswordFile or similar, as I suspect there are other
; file-opening calls (e.g. *CREATE) in IBOS
.openFile
{
    XASSERT_USE_PRV1
            LDX prvOswordBlockCopy + 12                                                   ;low byte of filename in I/O processor
            LDY prvOswordBlockCopy + 13                                                   ;high byte of filename in I/O processor
            JSR OSFIND
            CMP #&00
            BEQ GenerateNotFoundErrorIndirect
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
.^LA0A6
    XASSERT_USE_PRV1
       JSR getAddressesAndLengthFromPrvOswordBlockCopy
            BCS LA0B1 ; SFTODO: I don't believe this branch can ever be taken
            JSR PrepareMainSidewaysRamTransfer
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
    XASSERT_USE_PRV1
            SEC
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
    XASSERT_USE_PRV1
            LDA prvOswordBlockCopy + 10                                                  ;low byte of "data length", actually buffer length
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
    XASSERT_USE_PRV1
            LDA prvOswordBlockCopy + 10                                                  ;low byte of "data length", actually buffer length
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
    XASSERT_USE_PRV1
            PHA
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
    XASSERT_USE_PRV1
	  JSR copyOswordDetailsToPrv					;copy osword43 paramter block to Private memory &8220..&822F. Copy address of original block to Private memory &8230..&8231
            JSR adjustPrvOsword43Block					;convert pseudo RAM bank to absolute and shuffle parameter block
            BIT tubePresenceFlag					;check for Tube - &00: not present, &ff: present
            BPL NoTube 						;branch if tube not present
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
.LA16A      BIT tubeReg3Status
            BPL LA16A
            LDA tubeReg3Data
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
.NoTube
.^osword43Internal
    XASSERT_USE_PRV1
            JSR adjustOsword43LengthAndBuffer
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
            JSR CopyYxToVariableMainRamSubroutine								;relocate &32 bytes of code from either &9E83 or &9EAE to &03A7
            ; SFTODO: Is this code correct even ignoring the possible bug at
            ; adjustPrvOsword43Block? We seem to be trying to treat the data
            ; length as the buffer length - what if the data is longer than the
            ; buffer? Just possibly the "bug" is a misguided attempt to work
            ; around that. Speculation really as I still don't have the whole
            ; picture.
            LDA prvOswordBlockCopy + 10                                                             ;low byte of buffer length (SFTODO: bug? see adjustPrvOsword43Block)
            STA prvOswordBlockCopy + 6                                                              ;low byte of buffer length
            LDA prvOswordBlockCopy + 11                                                             ;high byte of buffer length (SFTODO: bug? see adjustPrvOsword43Block)
            STA prvOswordBlockCopy + 7                                                              ;high byte of buffer length
            PLA
            JSR openFile
            JSR getAddressesAndLengthFromPrvOswordBlockCopy
            JSR doTransfer
            JMP LA22B

.bufferLengthNotZero
; SFTODO: Does this assume the entire file fits into the buffer? Is that OK? Maybe 1770 DFS does the same?
.LA1C7      JSR PrepareMainSidewaysRamTransfer
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
.LA240      PRVEN								;switch in private RAM
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
.LA2DE      PRVDIS								;switch out private RAM
            JMP ExitAndClaimServiceCall								;Exit Service Call
}

.parseRomBankListChecked
{
            JSR parseRomBankList
            BCC rts
            BVC GenerateSyntaxErrorIndirect
.^badId
.LA2EB      JSR RaiseError								;Goto error handling, where calling address is pulled from stack

	  EQUB &80
	  EQUS "Bad id", &00

.GenerateSyntaxErrorIndirect
            JMP GenerateSyntaxErrorForTransientCommandIndex

	  ; SFTODO: Can we repurpose another nearby RTS and get rid of this?
.rts        RTS
}

;*INSERT Command
{
.^insert    JSR parseRomBankListChecked								;Error check input data
            LDX #userRegBankInsertStatus						;get *INSERT status
            JSR ReadUserReg								;Read from RTC clock User area. X=Addr, A=Data
            ORA transientRomBankMask								;update *INSERT status
            JSR WriteUserReg								;Write to RTC clock User area. X=Addr, A=Data
            LDX #userRegBankInsertStatus + 1
            JSR ReadUserReg								;Read from RTC clock User area. X=Addr, A=Data
            ORA transientRomBankMask + 1
            JSR WriteUserRegAndCheckNextCharI						;Check for Immediate 'I' flag
            BNE ExitAndClaimServiceCallIndirect1								;Exit if not immediate
            INY
            JSR insertBanksUsingTransientRomBankMask					;Initialise inserted ROMs
.ExitAndClaimServiceCallIndirect1
            JMP ExitAndClaimServiceCall								;Exit Service Call

.WriteUserRegAndCheckNextCharI
            JSR WriteUserReg								;Write to RTC clock User area. X=Addr, A=Data
            JSR FindNextCharAfterSpace							;find next character. offset stored in Y
            LDA (transientCmdPtr),Y
            AND #CapitaliseMask								;Capitalise
            CMP #'I'								;and check for 'I' (Immediate)
            RTS

;*UNPLUG Command
.^unplug	  JSR parseRomBankListChecked								;Error check input data
            JSR invertTransientRomBankMask								;Invert all bits in &AE and &AF
            LDX #&06								;INSERT status for ROMS &0F to &08
            JSR ReadUserReg								;Read from RTC clock User area. X=Addr, A=Data
            AND L00AE
            JSR WriteUserReg								;Write to RTC clock User area. X=Addr, A=Data
            LDX #&07								;INSERT status for ROMS &07 to &00
            JSR ReadUserReg								;Read from RTC clock User area. X=Addr, A=Data
            AND L00AF
            JSR WriteUserRegAndCheckNextCharI						;Check for Immediate 'I' flag
            BNE ExitAndClaimServiceCallIndirect2
            INY
            JSR unplugBanksUsingTransientRomBankMask
.ExitAndClaimServiceCallIndirect2
            JMP ExitAndClaimServiceCall								;Exit Service Call
}

{
SFTODOTMP = L00AA
SFTODOTMP2 = L00AB

.LA34A
    EQUB &00								;ROM at Banks 0 & 1
    EQUB &00								;ROM at Banks 2 & 3
    EQUB &04								;Check for RAM at Banks 4 & 5
    EQUB &08								;Check for RAM at Banks 6 & 7
    EQUB &10								;Check for RAM at Banks 8 & 9
    EQUB &20								;Check for RAM at Banks A & B
    EQUB &40								;Check for RAM at Banks C & D
    EQUB &80								;Check for RAM at Banks E & F

;*ROMS Command
.^roms
    LDA #maxBank:STA SFTODOTMP
.BankLoop
    JSR ShowRom
    DEC SFTODOTMP:BPL BankLoop
    JMP LA537 ; SQUASH: BMI always, maybe to equivalent code nearer by?
			
; SQUASH: This has only one caller
.ShowRom
    LDA SFTODOTMP:CLC:JSR PrintADecimal ; show bank number right-aligned
    JSR printSpace
    LDA #'(':JSR OSWRCH
    LDA SFTODOTMP:LSR A:TAY
    LDX #userRegRamPresenceFlags:JSR ReadUserReg
    AND LA34A,Y:BNE LA380 ; branch if this is a sideways RAM bank
    LDA #' ':BNE LA38D ; always branch
.LA380
    LDX SFTODOTMP:JSR TestRamUsingVariableMainRamSubroutine:PHP ; stash flags with Z set iff writeable
    LDA #'E' ; write-Enabled
    PLP:BEQ LA38D
    LDA #'P' ; Protected
.LA38D
    JSR OSWRCH
    PRVEN
    LDX SFTODOTMP:LDA romTypeTable,X
    LDY #' ' ; not unplugged
    AND #&FE ; bit 0 of ROM type is undefined, so mask out
    ; SFTODO: If we take this branch, will we ever do PRVDIS?
    BNE ShowRomHeader
    ; The romTypeTable entry is 0 so this ROM isn't active, but it may be one we've unplugged;
    ; if our private copy of the ROM type byte is non-0 show those flags.
    LDY #'U' ; Unplugged
    PRVEN ; SFTODO: We already did this, why do we need to do it again?
    LDA prvRomTypeTableCopy,X
    ; SFTODO: We don't AND #&FE here, is that wrong/inconsistent?
    PRVDIS
    BNE ShowRomHeader
    JSR printSpace ; ' ' in place of 'U'
    JSR printSpace ; ' ' in place of 'S'
    JSR printSpace; ' ' in place of 'L'
    LDA #')':JSR OSWRCH
    JMP OSNEWL

; Entered with Y=' ' or 'U' and rom type byte in A.
.ShowRomHeader
    PHA
    TYA:JSR OSWRCH
    LDX #'S' ; Service
    PLA:PHA:ASSERT romTypeService == 1 << 7:BMI HasServiceEntry
    LDX #' '
.HasServiceEntry
    TXA:JSR OSWRCH
    LDX #'L' ; Language
    PLA:AND #romTypeLanguage:BNE HasLanguageEntry
    LDX #' '
.HasLanguageEntry
    TXA:JSR OSWRCH
    LDA #')':JSR OSWRCH
    JSR printSpace
    ; Print the ROM title and version.
    LDA #lo(copyrightOffset):STA osRdRmPtr:LDA #hi(copyrightOffset):STA osRdRmPtr + 1
    LDY SFTODOTMP:JSR OSRDRM:STA SFTODOTMP2
    LDA #lo(title):STA osRdRmPtr:ASSERT hi(title) == hi(copyrightOffset)
.TitleAndVersionLoop
    LDY SFTODOTMP:JSR OSRDRM:BNE NotNul ; read byte and convert NUL at end of title to space
    LDA #' '
.NotNul
    JSR OSWRCH
    INC osRdRmPtr ; advance osRdRmPtr; we know the high byte isn't going to change
    LDA osRdRmPtr:CMP SFTODOTMP2:BCC TitleAndVersionLoop
    JMP OSNEWL
}

; Parse a list of bank numbers, returning them as a bitmask in transientRomBankMask. '*' can be used to indicate "everything but the listed banks". Return with C set iff at least one bit of transientRomBankMask is set.
.parseRomBankList
{
            LDA #&00
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
            BVS SecRts ; branch if not at end of line SFTODO: isn't this redundant? We just successfully checked and found a '*' not a CR? So we'll never branch, right? Should we have checked this earlier (e.g. at .noBankNumber)? Have I just got confused?
            INY
            JSR invertTransientRomBankMask
.LA429      LDA transientRomBankMask
            ORA transientRomBankMask + 1
            BEQ SecRts
            CLC
            RTS

; SFTODO: There's probably another copy of these two instructions we could re-use, though it might require shuffling code round and be more trouble than it's worth
.SecRts
            SEC
            RTS
}

; Set 16-bit word at transientRomBankMask to 1<<A, i.e. set it to 0 except bit A. Y is preserved.
; SFTODO: Am I missing something, or wouldn't it be far easier just to do a 16-bit rotate left in a loop? Maybe that wouldn't be shorter. Maybe this is performance critical? (Doubt it)
; SFTODO: I suspect this is creating some sort of ROM bank mask, but that is speculation at moment so label may be misleading.
.createRomBankMask
{
            PHA
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
; SFTODO: Would it be more compact to check for W-Z *first*, then use ConvertIntegerDefaultHex? This might only work if we do a "proper" upper case conversion, not sure.
            JSR FindNextCharAfterSpace								;find next character. offset stored in Y
            BCS endOfLine
            LDA (transientCmdPtr),Y
            CMP #','
            BNE LA464
            INY
.LA464      JSR ConvertIntegerDefaultDecimal
            BCC parsedDecimalOK
            LDA (transientCmdPtr),Y
            AND #CapitaliseMask                                                                                ;convert to upper case (imperfect but presumably good enough)
            CMP #'F'+1
            BCS LA47A
            CMP #'A'
            BCC LA492
            SBC #'A'-10
            JMP LA48B ; SFTODO: could probably do "BPL LA48B ; always branch" to save a byte
			
.LA47A      CMP #'Z'+1
            BCS LA492
            CMP #'W'
            BCC LA492
            SBC #'W'
            CLC
            ADC #prvPseudoBankNumbers - prv83
            TAX
            JSR ReadPrivateRam8300X								;read data from Private RAM &83xx (Addr = X, Data = A)
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
            JSR createRomBankMask
;Read ROM Type from ROM header for ROMs with a 1 bit in transientRomBankMask and save to ROM Type Table and Private RAM; used to immediately *INSERT a ROM without waiting for BREAK.
.^insertBanksUsingTransientRomBankMask
            PRVEN								;switch in private RAM


            LDY #maxBank
.bankLoop   ASL transientRomBankMask
            ROL transientRomBankMask + 1
            BCC SkipBank
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
.SkipBank   DEY
            BPL bankLoop
            PRVDIS								;switch out private RAM
            RTS
}
			
;Called by *UNPLUG Immediate
;Set bytes in ROM Type Table to 0 for banks with a 0 bit in transientRomBankMask; other banks are not touched.
.unplugBanksUsingTransientRomBankMask
{
            LDY #maxBank
.unplugLoop ASL transientRomBankMask
            ROL transientRomBankMask + 1
            BCS SkipBank
            LDA #&00
            STA romTypeTable,Y
.SkipBank   DEY
            BPL unplugLoop
            RTS
}
			
;Invert all bits in &AE and &AF
.invertTransientRomBankMask
    LDA transientRomBankMask:EOR #&FF:STA transientRomBankMask
    LDA transientRomBankMask + 1:EOR #&FF:STA transientRomBankMask + 1
    RTS


;Assign default pseudo RAM banks to absolute RAM banks
;For OSMODEs, 0, 1, 3, 4 & 5: W..Z = 4..7
;For OSMODE 2: W..Z = 12..15
; SFTODO: This has only one caller
; SFTODO: The OSMODE 2 behaviour seems weird; surely we *don't* have SWR in banks 12-15 (isn't IBOS in bank 15, for a start?), so while this is nominally B+-compatible (although not even that; doesn't the B+ have SWR in banks 0, 1, 12, 13 or something like that?), as soon as any softwre actually tries to work with these banks, won't it break? Maybe I'm missing something...
.assignDefaultPseudoRamBanks
{
.LA4E3      PRVEN								;switch in private RAM
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
            JSR ReadUserReg								;Read from RTC clock User area. X=Addr, A=Data
            ORA L00AE
            PLP
            PHP
            BCC LA520
            EOR L00AE
.LA520      JSR WriteUserReg								;Write to RTC clock User area. X=Addr, A=Data
            INX
            JSR ReadUserReg								;Read from RTC clock User area. X=Addr, A=Data
            ORA L00AF
            PLP
            BCC LA52E
            EOR L00AF
.LA52E      JSR WriteUserReg								;Write to RTC clock User area. X=Addr, A=Data
            PRVEN								;switch in private RAM
            JSR LA53D
.^LA537     PRVDIS								;switch out private RAM
            JMP ExitAndClaimServiceCall								;Exit Service Call
}

{
.^LA53D
     XASSERT_USE_PRV1
      LDX #userRegBankWriteProtectStatus
            JSR ReadUserReg								;Read from RTC clock User area. X=Addr, A=Data
            STA prvTmp
            INX
            JSR ReadUserReg								;Read from RTC clock User area. X=Addr, A=Data
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
.service10
{
    SEC
            JSR SFTODOALARMSOMETHING
            BCS LA570
            JMP SoftReset ; SFTODO: Rename this label given its use here?
			
.LA570      LDA ramselCopy
            AND #ramselShen
            STA ramselCopy

            PRVEN								;switch in private RAM

            JSR LA53D

;copy ROM type table to Private RAM
            LDX #maxBank
.CopyLoop   LDA romTypeTable,X
            STA prvRomTypeTableCopy,X
            DEX
            BPL CopyLoop

            PRVDIS								;switch out private RAM

            LDX lastBreakType
            BEQ SoftReset
            LDA #osbyteKeyboardScanFrom10
            JSR OSBYTE
            CPX #keycodeAt
            BNE SoftReset ; SFTODO: Rename label given use here?
            LDA #&00
            STA L0287
            LDA #&FF
            STA L03A4

	  ; SFTODO: Seems superficially weird we do this ROM type manipulation in response to this particular service call
;Set all bytes in ROM Type Table and Private RAM to 0
            LDX #maxBank
.ZeroLoop   CPX romselCopy ; SFTODO: are we confident romselCopy doesn't have b7/b6 set??
            BEQ SkipBank
            LDA #&00
            STA romTypeTable,X
            STA romPrivateWorkspaceTable,X
.SkipBank   DEX
            BPL ZeroLoop

            JMP finish

	  ; SFTODO: Seems superficially weird we do this ROM type manipulation in response to this particular service call
.SoftReset  LDA #&00
            STA L03A4
            LDX #userRegBankInsertStatus
            JSR ReadUserReg								;Read from RTC clock User area. X=Addr, A=Data
            STA transientRomBankMask
            LDX #userRegBankInsertStatus + 1
            JSR ReadUserReg								;Read from RTC clock User area. X=Addr, A=Data
            STA transientRomBankMask + 1
            JSR unplugBanksUsingTransientRomBankMask
	  ; SFTODO: Next bit of code is either claiming or not claiming the service call based on prvSFTODOTUBEISH; it will return with A=&10 (this call) or 0.
.finish     LDX #prvSFTODOTUBEISH - prv83
            JSR ReadPrivateRam8300X							;read data from Private RAM &83xx (Addr = X, Data = A)
            EOR #&FF
            AND #&10
            TSX
            STA L0103,X								;modify stacked A, i.e. A we will return from service call with
            JMP ExitServiceCall								;restore service call parameters and exit
}
			
;Write contents from Private memory address &8000 to screen
.PrintDateBuffer
{
    XASSERT_USE_PRV1
    LDX #0
.Loop
    LDA prvDateBuffer,X:BEQ Rts
    JSR OSASCI
    INX:CPX prvDateSFTODO1b:BCC Loop
.Rts
    RTS
}

;store #&05, #&84, #&44 and #&EB to addresses &8220..&8223, but why???
.InitDateSFTODOS
{
    XASSERT_USE_PRV1
    LDA #&05:STA prvDateSFTODO0 ; SFTODO: Is this really used? It just possibly is visible to caller via some Integra-B oswords...
    LDA #&84:STA prvDateSFTODO1 ; SFTODO: b7 of this is tested e.g. at LAD7F
    LDA #&40 OR prvDateSFTODO2UseHours:STA prvDateSFTODO2
    LDA #&EB:STA prvDateSFTODO3
    RTS
}

; Multiply 8-bit values prvA and prvB to give a 16-bit result at prvDC.
.mul8
{
    XASSERT_USE_PRV1
            LDA #&00
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
    XASSERT_USE_PRV1
    LDX #8 ; 8-bit division
    ; If prvB>=prvC, return with prvD=prvA, A=prvB.
    LDA prvA:STA prvD
    LDA prvB
    CMP prvC:BCS Rts ; SFTODO: branch if prvB>=prvC
    ; SFTODO: Set prvD=prvA DIV prvC, A=prvA MOD prvC
.Loop
    ROL prvD
    ROL A
    CMP prvC
    BCC NeedBorrow
    SBC prvC
.NeedBorrow
    DEX:BNE Loop
    ROL prvD
.Rts
    RTS
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

; Copy prvDate{Hours,Minutes,Seconds} to the RTC time registers, and set the RTC DSE flag
; according to userRegOsModeShx.
.CopyPrvTimeToRtc
{
    ; Force DV2/1/0 in register A on; this temporarily stops the RTC clock while we set it.
    LDX #rtcRegA:JSR ReadRtcRam:ORA #rtcRegADV2 OR rtcRegADV1 OR rtcRegADV0:JSR WriteRtcRam
    ; Force SET (set mode), DM (binary mode) and 2412 (24 hour mode) on in register B and
    ; force SQWE (square wave enable) and DSE (auto daylight savings adjust) off.
    LDX #rtcRegB:JSR ReadRtcRam ; SQUASH: ASSERT rtcRegA + 1 == rtcRegB:INX
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
    ; DELETE: If the DSE feature in the RTC doesn't use the right start/end dates for the UK,
    ; it might not be worth retaining the supporting code.
    LDX #userRegOsModeShx:JSR ReadUserReg
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

; Copy prvDate{DayOfWeek,DayOfMonth,Month,Year,Century} to the RTC date registers and
; userRegCentury.
.CopyPrvDateToRtc
    XASSERT_USE_PRV1
    JSR WaitOutRTCUpdate
    LDX #rtcRegDayOfWeek:LDA prvDateDayOfWeek:JSR WriteRtcRam
    INX:ASSERT rtcRegDayOfWeek + 1 == rtcRegDayOfMonth:LDA prvDateDayOfMonth:JSR WriteRtcRam
    INX:ASSERT rtcRegDayOfMonth + 1 == rtcRegMonth:LDA prvDateMonth:JSR WriteRtcRam
    INX:ASSERT rtcRegMonth + 1 == rtcRegYear:LDA prvDateYear:JSR WriteRtcRam
    LDX #userRegCentury:LDA prvDateCentury:JMP WriteUserReg

; Copy the RTC time registers to prvDate{Hours,Minutes,Seconds}.
.CopyRtcTimeToPrv
    XASSERT_USE_PRV1
    JSR WaitOutRTCUpdate
    LDX #rtcRegSeconds:JSR ReadRtcRam:STA prvDateSeconds
    LDX #rtcRegMinutes:JSR ReadRtcRam:STA prvDateMinutes
    LDX #rtcRegHours:JSR ReadRtcRam:STA prvDateHours
    RTS

; Copy the RTC date registers and userRegCentury to
; prvDate{DayOfWeek,DayOfMonth,Month,Year,Century}.
.CopyRtcDateToPrv
    XASSERT_USE_PRV1
    JSR WaitOutRTCUpdate
    LDX #rtcRegDayOfWeek:JSR ReadRtcRam:STA prvDateDayOfWeek
    INX:ASSERT rtcRegDayOfWeek + 1 == rtcRegDayOfMonth:JSR ReadRtcRam:STA prvDateDayOfMonth
    INX:ASSERT rtcRegDayOfMonth + 1 == rtcRegMonth:JSR ReadRtcRam:STA prvDateMonth
    INX:ASSERT rtcRegMonth + 1 == rtcRegYear:JSR ReadRtcRam:STA prvDateYear
    JMP GetUserRegCentury

; Copy time in RTC alarm registers to prvDate{Hours,Minutes,Seconds}.
.CopyRtcAlarmToPrv
    XASSERT_USE_PRV1
    JSR WaitOutRTCUpdate
    LDX #rtcRegAlarmSeconds:JSR ReadRtcRam:STA prvDateSeconds
    LDX #rtcRegAlarmMinutes:JSR ReadRtcRam:STA prvDateMinutes
    LDX #rtcRegAlarmHours:JSR ReadRtcRam:STA prvDateHours
    RTS

; Copy time in prvDate{Hours,Minutes,Seconds} into the RTC alarm registers.
.CopyPrvAlarmToRtc
    XASSERT_USE_PRV1
    JSR WaitOutRTCUpdate
    LDX #rtcRegAlarmSeconds:LDA prvDateSeconds:JSR WriteRtcRam
    LDX #rtcRegAlarmMinutes:LDA prvDateMinutes:JSR WriteRtcRam
    LDX #rtcRegAlarmHours:LDA prvDateHours:JMP WriteRtcRam ; SQUASH: move and fall through?

.CopyRtcDateTimeToPrv
    JSR CopyRtcDateToPrv
    JMP CopyRtcTimeToPrv ; SQUASH: move and fall through?

; SQUASH: Dead code
{
.CopyPrvDateTimeToRtc
    JSR CopyPrvTimeToRtc
    JMP CopyPrvDateToRtc
}

; Wait until any RTC update in progress	is complete.
.WaitOutRTCUpdate
{
    LDX #rtcRegA
.Loop
    JSR Nop3:STX rtcAddress
    JSR Nop3:LDA rtcData
    ASSERT rtcRegAUIP == &80:BMI Loop
    RTS
}

{
;Initialisation lookup table for RTC registers &00 to &09
.InitialRtcTimeValues
    EQUB 0  ; rtcRegSeconds
    EQUB 0  ; rtcRegAlarmSeconds
    EQUB 0  ; rtcRegMinutes
    EQUB 0  ; rtcRegAlarmMinutes
    EQUB 0  ; rtcRegHours
    EQUB 0  ; rtcRegAlarmHours
    EQUB 2  ; rtcRegDayOfWeek: Monday SFTODO: This will be 7 (Saturday) for IBOS 1.21, where we presumably default to 2000 not 1900
    EQUB 1  ; rtcRegDayOfMonth: 1st
    EQUB 1  ; rtcRegMonth: January
    EQUB 0  ; rtcRegYear: 1900 SFTODO: presumably 2000 in IBOS 1.21 as a result of changes elsewhere?
    ASSERT P% - InitialRtcTimeValues == (rtcRegYear - rtcRegSeconds) + 1

; SFTODO: Is this responsible for forcing reg B DSE bit off? This *would* matter if we wanted to use DSE.
; Initialise RTC time registers.
; SQUASH: This has only one caller.
.^InitialiseRtcTime
    LDX #rtcRegB:LDA #rtcRegBSET OR rtcRegBDM or rtcRegB2412:JSR WriteRtcRam
    ; SQUASH: Could we save code here by populating prvDate* with defaults and using
    ; WriteRtc{Time,Date} to do the update?
    ; Turn the divider off, temporarily stopping the RTC clock while we set it. We also try to
    ; set the read-only "update in progress" bit!
    ASSERT rtcRegB - 1 == rtcRegA:DEX
    LDA #rtcRegAUIP OR rtcRegADV2 OR rtcRegADV1:JSR WriteRtcRam
    ASSERT rtcRegA - 1 == rtcRegYear:DEX
.Loop
    LDA InitialRtcTimeValues,X:JSR WriteRtcRam
    DEX:BPL Loop:ASSERT rtcRegSeconds == 0
    RTS
}

.SFTODOALARMSOMETHING
{
Tmp = TransientZP + 6

    BCS LA7C2
    ; Set SQWE (square-wave enable) and if userRegAlarmEnableBit is set, additionally set AIE
    ; (alarm interrupt enable). Note that we *don't* clear AIE if it's currently set and
    ; userRegAlarmEnableBit isn't set. SFTODO: That's probably fine, but without more context
    ; it's possible this is a bug.
    LDX #userRegAlarm:JSR ReadUserReg:AND #userRegAlarmEnableBit
    ASSERT userRegAlarmEnableBit >> 1 == rtcRegBAIE:LSR A:STA Tmp
    LDX #rtcRegB:JSR ReadRtcRam:ORA #rtcRegBSQWE:ORA L00AE:JSR WriteRtcRam
.ClcRts
    CLC
    RTS

    ; Return with the current SQWE (square-wave enable) state in C.
.LA7C2
    LDX #rtcRegB:JSR ReadRtcRam:AND #rtcRegBSQWE:BNE ClcRts
    SEC
    RTS

; Return with C set iff prvDate{Century,Year} is a leap year.
.^TestLeapYear
    XASSERT_USE_PRV1
    LDA prvDateYear:CMP #0:BNE NotYear0 ; SQUASH: "CMP #0" is redundant
    LDA prvDateCentury
.NotYear0
    ; Set C iff A is divisible by 4.
    LSR A:BCS ClcRts
    LSR A:BCS ClcRts
    SEC
    RTS
}

; Return number of days in month Y in prvDate{Century,Year} in A.
.GetDaysInMonthY
{
   DEY:LDA MonthDaysTable,Y:INY ; SQUASH: Just do "LDA MonthDaysTable-1,Y" to avoid DEY/INY
   ; Add the leap day if this is February in a leap year.
   CPY #2:BNE Rts
   PHA:JSR TestLeapYear:PLA:BCC Rts
   LDA #29
.Rts
   RTS

; Lookup table for number of days in each month
.MonthDaysTable
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

; Set prvDateSFTODO4 to the day number of prvDate{DayOfMonth,Month} in the current year, with
; 1st January being 0.
; ENHANCE: That's what this should do but there's a bug; see ENHANCE: comment below.
; SQUASH: This has only one caller
.ConvertDateToRelativeDayNumber
{
    XASSERT_USE_PRV1
    LDA #0:STA prvDateSFTODO4:STA prvDateSFTODO4 + 1

    ; Count the days in the complete months (if any) before prvDateMonth.
    LDY #0 ; SQUASH: TAY
.PrecedingMonthLoop
    INY:CPY prvDateMonth:BEQ CountedDaysInPrecedingMonths
    JSR GetDaysInMonthY
    CLC:ADC prvDateSFTODO4:STA prvDateSFTODO4
    LDA prvDateSFTODO4 + 1:ADC #0:STA prvDateSFTODO4 + 1 ; SQUASH: INCCS prvDateSFTODO4 + 1
    BCC PrecedingMonthLoop ; always branch SQUASH: careful if change to INCCS in previous line
    RTS ; SQUASH: redundant, BCC will always branch (prvSFTODODATE4 will always be <365)

    ; Count the days up to but not including prvDateDayOfMonth in the current month.
.CountedDaysInPrecedingMonths
    LDX prvDateDayOfMonth:DEX:TYA ; ENHANCE: This is buggy; TYA should be TXA, see test/date.bas.
    CLC:ADC prvDateSFTODO4:STA prvDateSFTODO4
    LDA prvDateSFTODO4 + 1:ADC #0:STA prvDateSFTODO4 + 1 ; SQUASH: INCCS prvDateSFTODO4 + 1
    RTS
}

{
; SFTODO: Both of these return with bits set in prvDateSFTODOQ for errors - does anything actually check this except to see if it's 0/non-0?
; SFTODO: This entry point validates days in February based on prvDate{Century,Year}
.^ValidateDateTimeRespectingLeapYears
    CLC:BCC Common ; always branch
; SFTODO: This entry point always allows 29th February regardless
.^ValidateDateTimeAssumingLeapYear ; SFTODO: perhaps not ideal name
    SEC
.Common
     ; SFTODO: Does anything actually check the individual bits in the result we build up? If not this code could potentially be simplified. Pretty sure we do but need to check.
    XASSERT_USE_PRV1
    PHP
    LDA prvDateCentury:LDX #0:LDY #99:JSR CheckABetweenXAndY:LDA #prvDateSFTODOQCentury:JSR RecordCheckResultForA
    LDA prvDateYear:LDX #0:LDY #99:JSR CheckABetweenXAndY:LDA #prvDateSFTODOQYear:JSR RecordCheckResultForA
    LDA prvDateMonth:LDX #1:LDY #12:JSR CheckABetweenXAndY:LDA #prvDateSFTODOQMonth:JSR RecordCheckResultForA
    ; Set Y to the maximum acceptable day of the month; if the month is open we can allow days up to and including 31.
    PLP:BCC LookupMonthDays
    LDA prvDateMonth:CMP #&FF:BNE MonthNotOpen
    LDY #31:BNE MaxDayOfMonthInY ; always branch
.MonthNotOpen
    CMP #2:BNE LookupMonthDays ; February is a special case
    LDY #29:BNE MaxDayOfMonthInY ; always branch
.LookupMonthDays
    LDY prvDateMonth:JSR GetDaysInMonthY:TAY
.MaxDayOfMonthInY
    LDA prvDateDayOfMonth:LDX #1:JSR CheckABetweenXAndY:LDA #prvDateSFTODOQDayOfMonth:JSR RecordCheckResultForA
    ; SFTODO: Why do we allow prvDateDayOfWeek to be 0?
    LDA prvDateDayOfWeek:LDX #0:LDY #7:JSR CheckABetweenXAndY:LDA #prvDateSFTODOQDayOfWeek:JSR RecordCheckResultForA
    LDA prvDateHours:LDX #0:LDY #23:JSR CheckABetweenXAndY:LDA #prvDateSFTODOQHours:JSR RecordCheckResultForA
    LDA prvDateMinutes:LDX #0:LDY #59:JSR CheckABetweenXAndY:LDA #prvDateSFTODOQMinutes:JSR RecordCheckResultForA
    LDA prvDateSeconds:JSR CheckABetweenXAndY:LDA #prvDateSFTODOQSeconds:FALLTHROUGH_TO RecordCheckResultForA

; Set the bits set in A in prvOswordBlock if C is set, clear them if C is clear.
.RecordCheckResultForA
    BCC RecordOk ; SFTODO: could we just BCC rts if we knew prvDateSFTODOQ was 0 to start with? Do we re-use A values?
    ORA prvDateSFTODOQ
    STA prvDateSFTODOQ
    RTS
.RecordOk
    EOR #&FF
    AND prvDateSFTODOQ
    STA prvDateSFTODOQ
    RTS

; Return with C clear iff X<=A<=Y.
.CheckABetweenXAndY
    STA prvTmp2
    CPY prvTmp2
    BCC SecRts
    STX prvTmp2
    CMP prvTmp2
    BCC SecRts ; SFTODO: Any chance of using another copy of these instructions?
    CLC
    RTS
.SecRts
    SEC
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
; As calculateDayOfWeekInA, except we also update prvDateDayOfWeek with the calculated day of the week, and set SFTODO:PROBABLY b3 of prvDateSFTODOQ if this changes prvDateDayOfWeek from its previous value.
.^calculateDayOfWeekInPrvDateDayOfWeek
            CLC
            BCC LA909
; SFTODO: Use a magic formula to calculate the day of the week for prvDate{Century,Year,Month,DayOfMonth}; I don't know how this works, but presumably it does.
; We return with the calculated day of the week in A.
.^calculateDayOfWeekInA
            SEC
.LA909
    XASSERT_USE_PRV1
      PHP
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
            LDA prvDC:SBC #19:STA prvA
            LDA prvDC + 1:SBC #0:STA prvB
	  ; SFTODO: So BA=prvTmp4*130-19??
            LDA #100:STA prvDC
            JSR SFTODOPSEUDODIV ; SFTODO: Don't really know what's going on here yet, but I think this *could* invoke the weird prvB>=prvC condition in SFTODOPSEUDODIV.
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
            LDA #0:STA prvB
            LDA #7:STA prvC
            JSR SFTODOPSEUDODIV ; SFTODO: HERE WE WILL DIVIDE WITHOUT ANY WEIRDNESS
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
	  ; SFTODO: I think it's right to be using the SFTODOQ labels here but not sure yet
            LDA #prvDateSFTODOQDayOfWeek
            ORA prvDateSFTODOQ
            STA prvDateSFTODOQ
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

    XASSERT_USE_PRV1
            LDA #1
            STA prvDateDayOfMonth
            JSR calculateDayOfWeekInPrvDateDayOfWeek
            LDY prvDateMonth
            JSR GetDaysInMonthY
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
.DayOfMonthLoop
            LDA prvDateDayOfMonth
            CMP daysInMonth
            BCC notDone ; SFTODO: Could we BCS to a nearby RTS (there's one just above) to save a byte
            RTS
.notDone    ADC prvDateDayOfWeek
            SEC:SBC #2:STA prvA
            LDA #0:STA prvB
            LDA #7:STA prvC
            JSR SFTODOPSEUDODIV ; SFTODO: WILL ALWAYS DIVIDE WITH NO WEIRDNESS
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
            JMP DayOfMonthLoop
}

{
.^DayMonthNames
.Today
    EQUS "today" ; *DATE/*CALENDAR date calculations understand "today"; not used on output
.Sunday
    EQUS "sunday"
.Monday
    EQUS "monday"
.Tuesday
    EQUS "tuesday"
.Wednesday
    EQUS "wednesday"
.Thursday
    EQUS "thursday"
.Friday
    EQUS "friday"
.Saturday
    EQUS "saturday"
.January
    EQUS "january"
.February
    EQUS "february"
.March
    EQUS "march"
.April
    EQUS "april"
.May
    EQUS "may"
.June
    EQUS "june"
.July
    EQUS "july"
.August
    EQUS "august"
.September
    EQUS "september"
.October
    EQUS "october"
.November
    EQUS "november"
.December
    EQUS "december"
.End
	
; String offsets in DayMonthNames
.^DayMonthNameOffsetTable
    EQUB Today     - DayMonthNames
    EQUB Sunday    - DayMonthNames
    EQUB Monday    - DayMonthNames
    EQUB Tuesday   - DayMonthNames
    EQUB Wednesday - DayMonthNames
    EQUB Thursday  - DayMonthNames
    EQUB Friday    - DayMonthNames
    EQUB Saturday  - DayMonthNames
    EQUB January   - DayMonthNames
    EQUB February  - DayMonthNames
    EQUB March     - DayMonthNames
    EQUB April     - DayMonthNames
    EQUB May       - DayMonthNames
    EQUB June      - DayMonthNames
    EQUB July      - DayMonthNames
    EQUB August    - DayMonthNames
    EQUB September - DayMonthNames
    EQUB October   - DayMonthNames
    EQUB November  - DayMonthNames
    EQUB December  - DayMonthNames
    EQUB End       - DayMonthNames
}


; Emit name of day (C clear on entry) or month (C set on entry) in A as a string to
; transientDateBuffer. The name will be truncated to X characters (X=0 => no truncation) and
; will be all-caps if Y=0 on entry, first character capitalised otherwise.
.EmitDayOrMonthName
{
EndCalOffset = prvTmp2
LocalCapitaliseMask = prvTmp3
MaxOutputLength = prvTmp4 ; SFTODO: rename this, I think it's "max chars to print"

    XASSERT_USE_PRV1
    BCC IndexInA
    ; We're outputting a month, so adjust A to skip past the day of week entries in
    ; DayMonthNameOffsetTable.
    ; SQUASH: don't clear C and ADC #daysPerWeek - 1
    CLC:ADC #daysPerWeek
.IndexInA
    STX MaxOutputLength
    CPY #0:BNE UseLowerCase
    LDY #CapitaliseMask:STY LocalCapitaliseMask
    JMP LocalCapitaliseMaskSet ; SQUASH: BNE always
.UseLowerCase
    LDY #&FF:STY LocalCapitaliseMask
.LocalCapitaliseMaskSet
    ; Set X and EndCalOffset so the string to print is at DayMonthNames+[X, EndCaloffset).
    TAX
    INX:LDA DayMonthNameOffsetTable,X:STA EndCalOffset ; SQUASH: Use DayMonthNameOffsetTable+1 to avoid INX/DEX
    DEX:LDA DayMonthNameOffsetTable,X:TAX
    ; Write the string into transientDateBuffer; we always capitalise the first character and
    ; use LocalCapitaliseMask for the rest.
    LDY transientDateBufferIndex
    LDA DayMonthNames,X:AND #CapitaliseMask:JMP CharInA ; SQUASH: BNE always
.Loop
    LDA DayMonthNames,X:AND LocalCapitaliseMask
.CharInA
    STA (transientDateBufferPtr),Y
    INY:INX:DEC MaxOutputLength:BEQ Done
    CPX EndCalOffset:BNE Loop
.Done
    STY transientDateBufferIndex
    RTS
}
			
{
tensChar = prvTmp2
unitsChar = prvTmp3

; Emit A (<=99) into transientDateBuffer, formatted as a decimal number according to X:
;   A    0     5     25
; X=0 => "00"  "05"  "25"	Right-aligned in a two character field with leading 0s
; X=1 => "0"   "5"   "25"	Left-aligned with no padding, 1 or 2 characters
; X=2 => " 0"  " 5"  "25"	Right-aligned in a two character field with no leading 0s
; X=3 => "  "  " 5"  "25"	Right-aligned in a two character field with no leading 0s, 0 shown as blank
.^emitADecimalFormatted ; SFTODO: should have ToDateBuffer in name
    XASSERT_USE_PRV1
            JSR convertAToTensUnitsChars						;Split number in register A into 10s and 1s, characterise and store units in &824F and 10s in &824E
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
            JMP EmitAToDateBufferUsingY							;store at buffer &XY?Y, increase buffer pointer, save buffer pointer and return.

;postfix for dates. eg 25th, 1st, 2nd, 3rd
.dateSuffixes
    EQUS "th", "st", "nd", "rd"

; Emit ordinal suffix for A (<=99) into transientDateBuffer; if C is set it will be capitalised.
; SFTODO: This only has one caller, can it just be inlined?
.^EmitOrdinalSuffix
    XASSERT_USE_PRV1
            PHP									;save carry flag. Used to select capitalisation
            JSR convertAToTensUnitsChars						;Split number in register A into 10s and 1s, characterise and store units in &824F and 10s in &824E
            LDA tensChar								;get 10s
            CMP #'1'								;check for '1'
            BNE not1x								;branch if not 1.
.thSuffix   LDX #&00								;if the number is in 10s, then always 'th'
            JMP SuffixInX ; SFTODO: Could BEQ ; always
			
.not1x      LDA unitsChar								;get 1s
            CMP #'4'								;check if '4'
            BCS thSuffix								;branch if >='4'
            AND #&0F								;mask lower 4 bits, converting ASCII digit to binary
            ASL A									;x2 - 1 becomes 2, 2 becomes 4, 3 becomes 6
            TAX
.SuffixInX  PLP									;restore carry flag. Used to select capitalisation
            LDY transientDateBufferIndex						;get buffer pointer
            LDA dateSuffixes,X							;get 1st character from table + offset
            BCC noCaps1								;don't capitalise
            AND #CapitaliseMask								;capitalise
.noCaps1    STA (transientDateBufferPtr),Y						;store at buffer &XY?Y
            INY									;increase buffer pointer
            LDA dateSuffixes+1,X							;get 2nd character from table + offset
            BCC noCaps2								;don't capitalise
            AND #CapitaliseMask								;capitalise
.noCaps2    JMP EmitAToDateBufferUsingY							;store at buffer &XY?Y, increase buffer pointer, save buffer pointer and return

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
.AmPmSuffixes
	  EQUS "am", "pm"

; Emit "am" or "pm" time suffix for hour A (<=23) into transientDateBuffer.
; SFTODO: This only has one caller, could it just be inlined?
.^EmitAmPmForHourA
    TAX:CPX #0:BNE Not0Hours ; SQUASH: "CPX #0" is redundant
    LDX #24
.Not0Hours
    LDA #0:CPX #13:ADC #0:ASL A:TAX ; set X=0 if X<13, X=2 if X>=13
    LDY transientDateBufferIndex:LDA AmPmSuffixes,X:STA (transientDateBufferPtr),Y:INY
    LDA AmPmSuffixes + 1,X:JMP EmitAToDateBufferUsingY
}

IF FALSE
; SQUASH: EmitAmPmForHourA is a bit more complex than necessary - here's a shorter alternative implementation, not tested!
.EmitAmPmForHourA
{
    LDX #'a'
    TAY:BEQ SuffixInX ; branch if 00 hrs ('am')
    CMP #13:BCC SuffixInX ; branch if A<13 (hrs) ('am')
    LDX #'p' ; ('pm')
.SuffixInX
    TXA:JSR EmitAToDateBuffer
    LDA #'m':FALLTHROUGH_TO EmitAToDateBuffer
}
ENDIF
			
{
; Store A in transientDateBuffer at offset transientDateBufferIndex, incrementing it afterwards.
.^EmitAToDateBuffer
    LDY transientDateBufferIndex

; Store A in transientDateBuffer at offset Y, incrementing it and setting
; transientDateBufferIndex to Y afterwards.
.^EmitAToDateBufferUsingY
    STA (transientDateBufferPtr),Y
    INY:STY transientDateBufferIndex
    RTS
}

; Emit hours/minutes/seconds to the date buffer with formatting controlled by prvDateSFTODO2. C
; is clear on exit iff something was emitted.
;
; SQUASH: I believe most of this complexity is only used via OSWORD &49 with XY?0=&62; all the
; internal callers seem to have prvDateSFTODO2 AND prvDateSFTODO2TimeMask ==
; prvDateSFTODO2UseHours.
; SFTODO: It would perhaps be nice to verify my analysis of prvDateSFTODO2* flags by invoking
; that OSWORD call from a test program.

; SFTODOWIP COMMENT - CAN PROBABLY DELETE THE BELOW NOW I HAVE prvDateSFTODO2* BIT CONSTANTS, BUT KEEP AROUND FOR NOW
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
.EmitTimeToDateBuffer
{
Options = transientDateSFTODO1

    XASSERT_USE_PRV1
    LDA prvDateSFTODO2:AND #prvDateSFTODO2TimeMask:STA Options
    BNE SomethingToDo ; SQUASH: BEQ to a nearby SEC:RTS?
    SEC
    RTS
.SomethingToDo
    LDA Options:CMP #prvDateSFTODO2UseHours:BCC ShowMinutes
    ; Emit hours.
    LDX #0 ; X is formatting option for emitADecimalFormatted; 0 means "00" style.
    ; SQUASH: Omit EOR and use BEQ instead of BNE?
    AND #prvDateSFTODO2NoLeadingZero:EOR #prvDateSFTODO2NoLeadingZero:BNE LeadingZero
    INX:INX ; X=2 => emitADecimalFormatted will use " 0" style
.LeadingZero
    LDA Options:AND #prvDateSFTODO212Hour:PHP
    LDA prvDateHours
    PLP:BEQ HoursInA
    ; Convert 24 hour to 12 hour time.
    LDA prvDateHours:BEQ ZeroHours
    CMP #13:BCC HoursInA
    SBC #12:BCS HoursInA ; always branch
.ZeroHours
    LDA #12 ; 12am
.HoursInA
    JSR emitADecimalFormatted
    LDA #':':JSR EmitAToDateBuffer

.ShowMinutes
    LDX #0 ; X is formatting option for emitADecimalFormatted; 0 means "00" style.
    LDA Options
    CMP #prvDateSFTODO2UseHours:BCS ShowMinutesAs00 ; branch if hour shown
    CMP #prvDateSFTODO212Hour:BEQ ShowMinutesAs00 ; branch if 24 hour clock
    ; Options could be 0, 2 or 3 here but I suspect in practice it will either be 0 or 2, and
    ; thus this is effectively using prvDateSFTODO2NoLeadingZero to select "00" or " 0" format.
    TAX ; X is formatting option for emitADecimalFormatted
.ShowMinutesAs00
    LDA prvDateMinutes:JSR emitADecimalFormatted
    LDA Options
    CMP #prvDateSFTODO2MinutesControl:BCC separatorColon
    CMP #prvDateSFTODO2MinutesControl OR prvDateSFTODO2UseHours:BCC ShowAmPm
    LDA #'/'
    BNE separatorInA ; always branch
.separatorColon
    LDA #':'
.separatorInA
    JSR EmitAToDateBuffer
    LDX #0:LDA prvDateSeconds:JSR emitADecimalFormatted ; emit seconds using "00" format

.ShowAmPm
    LDA Options:CMP #prvDateSFTODO2UseHours:BCC Finish
    LDA Options:AND #prvDateSFTODO212Hour:BEQ Finish ; SQUASH: "LDA options" is redundant
    LDA #' ':JSR EmitAToDateBuffer
    LDA prvDateHours:JSR EmitAmPmForHourA
.Finish
    CLC
    RTS
}

;Separators for Time Display? SFTODO: seems probable, need to update this comment when it becomes clear
.dateSeparators ; SFTODO: using "date" for consistency with prvDate* variables, maybe revisit after - all the "time"/"date"/"calendar" stuff has a lot of common code
    EQUS " ", "/", ".", "-"

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
    XASSERT_USE_PRV1
; SFTODO: Experimentally using nested scopes here to try to make things clearer, by making it more obvious that some labels have restricted scope - not sure if this is really helpful, let's see
; SFTODO: Chopping the individual blocks up into macros might make things clearer?
; 1. Optionally emit the day of the week, optionally truncated and/or capitalised, and optionally followed by some punctuation. prvDataSFTODO2's high nybble controls most of those options, although prvDataSFTODO3=0 will prevent punctuation and cause an early return.
    {
	  LDA prvDateSFTODO2
	  ; SFTODO: Use LsrA4
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
            JSR EmitDayOrMonthName							;X is maximum number of characters to emit, Y controls capitalisation
            LDA prvDateSFTODO3
            BNE LACA0
            JMP LAD5Arts

.LACA0      LDA prvDateSFTODO1
            AND #&0F
            STA transientDateSFTODO1
            CMP #&04
            BCC LACB6
            LDA #','
            JSR EmitAToDateBuffer							;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
            LDA transientDateSFTODO1
            CMP #&08
            BCC SFTODOSTEP2
.LACB6      LDA #' '
            JSR EmitAToDateBuffer							;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
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
            JSR EmitOrdinalSuffix							;Convert to text, then save to buffer XY?Y, increment buffer address offset.
.LACE5      LDA prvDateSFTODO3
            AND #&F8
            BEQ LAD5Arts
            LDA prvDateSFTODO1
            AND #&03								;mask lower 3 bits
            TAX
            LDA dateSeparators,X							;get character from look up table
            JSR EmitAToDateBuffer							;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
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
            JSR EmitDayOrMonthName							;X is max characters to emit, Y controls capitalisation
.LAD2A      LDA prvDateSFTODO3
            AND #&C0
            BEQ LAD5Arts
            LDA prvDateSFTODO1
            AND #&03								;mask lower 3 bits
            TAX
            LDA dateSeparators,X								;get character from look up table
            JSR EmitAToDateBuffer								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
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
            JSR EmitAToDateBuffer								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
            JMP emitYear
    }
}
			

;read buffer address from &8224 and store at &A8
;set buffer pointer to 0
.InitDateBufferAndEmitTimeAndDate
{
    XASSERT_USE_PRV1
    LDA prvDateSFTODO4:STA transientDateBufferPtr:LDA prvDateSFTODO4 + 1:STA transientDateBufferPtr + 1
    LDA #0:STA transientDateBufferIndex
    JSR EmitTimeAndDateToDateBuffer
    LDA #vduCr:JSR EmitAToDateBuffer
    LDY transientDateBufferIndex:STY prvDateSFTODO1b
.^LAD7Erts
    RTS

; SFTODO: Next line implies b7 of prvDateSFTODO1 "mainly" controls ordering (whether time or date comes first)
.EmitTimeAndDateToDateBuffer
    BIT prvDateSFTODO1:BMI DateFirst
    JSR EmitTimeToDateBuffer
    JSR emitSeparatorToDateBuffer
    JMP emitDateToDateBuffer
.DateFirst
    JSR emitDateToDateBuffer
    JSR emitSeparatorToDateBuffer
    JMP EmitTimeToDateBuffer
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
    XASSERT_USE_PRV1
            LDA prvDateSFTODO1
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
            JSR EmitAToDateBuffer								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
            LDA transientDateSFTODO1
            AND #&10
            BEQ LAD7Erts
.emitSpace      LDA #' '
            JMP EmitAToDateBuffer								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
			
.emitSpaceAtSpace      LDA #' '
            JSR EmitAToDateBuffer								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
            LDA #'@'
            JSR EmitAToDateBuffer								;save the contents of A to buffer address + buffer address offset, then increment buffer address offset
            JMP emitSpace
}

; SFTODO: "Ish" in name because I think this will be affected by the bug in ConvertDateToRelativeDayNumber
; SFTODO: This has only one caller
; Set prvDateSFTODO4 to be the 16-bit absolute day number of prvDate*, where 1st January 1900 is day 0.
.ConvertDateToAbsoluteDayNumber
{
    XASSERT_USE_PRV1
            LDA #0
            STA prvDateSFTODOX
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
            JSR ConvertDateToRelativeDayNumber
            CLC
            LDA prvDateSFTODO4
            ADC prvDC
            STA prvDateSFTODO4
            LDA prvDateSFTODO4 + 1
            ADC prvDC + 1
            STA prvDateSFTODO4 + 1
	  ; We have now (SFTODO: ignoring possible bug in ConvertDateToRelativeDayNumber) calculated the number of days from January 1st 1900 to prvDate.
            BCS LAE26 ; branch if we've overflowed SFTODO: pointless? well, at least inconsistent/incomplete?
            RTS
			
.LAE26      LDA #&FF
            STA prvDateSFTODOX
            RTS
}

; Convert a 16-bit absolute day number (1st January 1900 being day 0) in prvDateSFTODO4 into a
; component-based date in prvDate{DayOfWeek,DayOfMonth,Month,Year,Century}.
; SQUASH: This has only one caller
.ConvertAbsoluteDayNumberToDate
{
DaysBetween1stJan1900And2000 = 36524 ; frink: #2000/01/01#-#1900/01/01# -> days

    XASSERT_USE_PRV1
    ; If prvDateSFTODO4 < DaysBetween1stJan1900And2000, this is a 19xx date, otherwise it's a
    ; 20xx date. If it's a 20xx date we set prvDateSFTODO4 -= DaysBetween1stJan1900And2000.
    LDA #19:STA prvDateCentury
    SEC
    LDA prvDateSFTODO4:SBC #lo(DaysBetween1stJan1900And2000):STA prvA
    LDA prvDateSFTODO4 + 1:SBC #hi(DaysBetween1stJan1900And2000):BCC CenturyOK
    STA prvDateSFTODO4 + 1
    LDA prvA:STA prvDateSFTODO4
    INC prvDateCentury
.CenturyOK
    ; At this point prvDateSFTODO4 is the number of days from 1st January (prvCentury)00. Count
    ; up from year 0, subtracting off the number of days in the year until prvDateSFTODO4 would
    ; go negative, indicating we don't have a full year left.
    LDA #0:STA prvDateYear
.FullYearLoop
    JSR TestLeapYear ; set C iff prvDateYear is a leap year
    LDA #lo(daysPerYear):ADC #0:STA prvA
    LDA #hi(daysPerYear):STA prvB
    SEC
    LDA prvDateSFTODO4:SBC prvA:STA prvA
    LDA prvDateSFTODO4 + 1:SBC prvB:BCC NotFullYear
    STA prvDateSFTODO4 + 1
    LDA prvA:STA prvDateSFTODO4
    INC prvDateYear
    JMP FullYearLoop ; SQUASH: BPL always branch?
.NotFullYear
    ; Now count up through the full months, subtracting off the number of days in each month
    ; until prvDateSFTODO4 would go negative, indicating we don't have a full month left.
    LDA #1:STA prvDateMonth
.FullMonthLoop
    LDY prvDateMonth:JSR GetDaysInMonthY
    STA prvA
    SEC:LDA prvDateSFTODO4:SBC prvA:STA prvA
    LDA prvDateSFTODO4 + 1:SBC #0:BCC NotFullMonth
    STA prvDateSFTODO4 + 1
    LDA prvA:STA prvDateSFTODO4
    INC prvDateMonth
    JMP FullMonthLoop ; SQUASH: BPL always branch?
.NotFullMonth
    ; prvDateSFTODO4 is now the 0-based day within the month; add 1 to convert to the normal
    ; convention and finish by calculating the day of week.
    LDX prvDateSFTODO4:INX:STX prvDateDayOfMonth
    JMP calculateDayOfWeekInPrvDateDayOfWeek
}

{
; As IncrementPrvDateOpenElements, but it assumes prvDateDayOfMonth is open and advances it by
; seven days instead of one day as IncrementPrvDateOpenElements would.
; SQUASH: This has only one caller
.^IncrementPrvDateOpenElementsByOneWeek
    XASSERT_USE_PRV1
    CLC:LDA prvDateDayOfMonth:ADC #daysPerWeek:STA prvDateDayOfMonth
    LDY prvDateMonth:JSR GetDaysInMonthY
    CMP prvDateDayOfMonth:BCS clvClcRts
    ; Our addition made prvDateDayOfMonth > DaysInMonth, so fix that and bump the next open
    ; unit to compensate.
    STA prvTmp2
    SEC:LDA prvDateDayOfMonth:SBC prvTmp2:STA prvDateDayOfMonth
    JMP DayOfMonthIncremented ; SQUASH: BCS always?

; SFTODO: I am still figuring this code out, but what I think this is doing is incrementing the date part of PrvDate* - it's not a simple increment by 1, because we do *not* change anything the user has explicitly specified, we only change "open" elements the user didn't specify. Note that we need to continue to respect openness (it's really more that we're respecting *non*-openness) as we cascade the change into more significant parts of the date when the increment moves an element out of range.
; SFTODO: Whether we succeeded or not is indicated by C and V flags - there is probably a common pattern of these across all the date code, once I get a clearer picture
; Increment the open elements (as specified by prv2Flags) of prvDate* by one step. On exit:
;     C=1 means the century wrapped from 99xx to 00x (SFTODO: bit odd threshold, as we don't generally cope with dates outside 19/20xx, do we?)
;     C=0 means the century didn't wrap; V is set iff the year was incremented.
; SFTODO: Make permanent comment this does *not* pay any attention at all to day-of-week (neither does the ByOneWeek variant)
.^IncrementPrvDateOpenElements
    XASSERT_USE_PRV1
    LDA #prv2FlagDayOfMonth:BIT prv2Flags:BEQ DayOfMonthNotOpen
    INC prvDateDayOfMonth
    LDY prvDateMonth:JSR GetDaysInMonthY
    CMP prvDateDayOfMonth:BCS clvClcRts
    LDA #1:STA prvDateDayOfMonth
.DayOfMonthNotOpen
.DayOfMonthIncremented
    LDA #prv2FlagMonth:BIT prv2Flags:BEQ MonthNotOpen
    INC prvDateMonth
    LDA prvDateMonth:CMP #MonthsPerYear + 1:BCC clvClcRts
    LDA #1:STA prvDateMonth
.MonthNotOpen
    LDA #prv2FlagYear:BIT prv2Flags:BEQ YearNotOpen
    INC prvDateYear ; SFTODO: *probably* sets prvDateYear to 0 - but then why would we do the following, so maybe it doesn't?
    LDA prvDateYear:CMP #100:BCC sevClcRts
    LDA #0:STA prvDateYear
.YearNotOpen
    LDA #prv2FlagCentury:BIT prv2Flags:BEQ sevClcRts
    INC prvDateCentury
    LDA prvDateCentury:CMP #100:BCC sevClcRts
    LDA #0:STA prvDateCentury
    SEC
    RTS
			
.^clvClcRts
    CLV
    CLC
    RTS
			
.^sevClcRts
    BIT Rts
    CLC
.Rts
    RTS
}

; Decrement prvDate* by one day; this does not respect the open flags. On exit:
;     C=1 means the century wrapped from 00xx to 255x (SFTODO: bit odd threshold, as we don't generally cope with dates outside 19/20xx, do we?)
;     C=0 means the century didn't wrap; V is set iff the year was decremented.
.DecrementPrvDateBy1
{
    XASSERT_USE_PRV1
    DEC prvDateDayOfMonth:BNE clvClcRts
    LDY prvDateMonth:DEY:BNE MonthOk
    LDY #MonthsPerYear
.MonthOk
    JSR GetDaysInMonthY:STA prvDateDayOfMonth
    STY prvDateMonth
    CPY #MonthsPerYear:BCC clvClcRts
    DEC prvDateYear:LDA prvDateYear:CMP #&FF:BNE sevClcRts
    LDA #99:STA prvDateYear
    DEC prvDateCentury:LDA prvDateCentury:CMP #&FF:BNE sevClcRts
    SEC ; SFTODO: redundant?
    RTS
}

; SFTODO: I *BELIEVE* THIS POPULATES THE DOM/MONTH/YEAR/CENTURY BITS OF PRVDATE WITH THE EARLIEST DATE COMPATIBLE WITH THE CORRESPONDING BITS OF THE USER'S PARTIAL SPECIFICATION. THE RESULT MAY NOT MATCH - EG THE USER MAY HAVE SAID "SUNDAY" AND THIS DATE IS A MONDAY.
; SFTODO: ON EXIT C CLEAR MEANS WE POPULATED THOSE BITS OK, C SET MEANS WE COULDN'T FIND ANYTHING MATCHING THE RELEVANT BITS OF USER'S PARTIAL SPEC
.SFTODOProbDefaultMissingDateBitsAndCalculateDayOfWeek ; SFTODO: I think this is a poor (incomplete) label, because in the YearOpen case we are adjusting the date until we match the fixed parts
{
    XASSERT_USE_PRV1
    LDA prv2Flags:AND #prv2FlagYear:BNE YearOpen

    ; The year is not open. Default the century if it's open.
    LDA prv2Flags:AND #prv2FlagCentury:BEQ CenturyNotOpen
    LDA #19:STA prvDateCentury ; default century to 19 SFTODO: probably OK, but should we default to whatever the current century is instead, as we do elsewhere??
    LDA prv2Flags:AND #NOT(prv2FlagCentury) AND prv2FlagMask:STA prv2Flags ; clear bit indicating prvDateCentury is open
.CenturyNotOpen
    ; Now fill in open elements of prvDate{Century,Year,Month,DayOfMonth} with the
    ; corresponding elements of 1900/01/01.
    LDX #0
.DefaultLoop
    LDA prvDateCentury,X
    CMP #&FF:BNE ElementNotOpen
    TXA:LSR A ; generate defaults 0, 0, 1, 1.
.ElementNotOpen
    STA prvDateCentury,X
    INX:CPX #4:BNE DefaultLoop
    JMP FoundMatchingDate ; SQUASH: BEQ always

; SFTODOWIP
.YearOpen
    ; The user has left the year open; this is a special case because we use today as the
    ; starting point, not 1st January 1900.
    JSR CopyRtcDateToPrv
    ; If the user partial date specification has everything except (perhaps) day-of-week
    ; specified, the date is already fully specified.
    LDA prv2Flags
    AND #NOT(prv2FlagDayOfWeek) AND prv2FlagMask
    CMP #NOT(prv2FlagDayOfWeek) AND prv2FlagMask
    BEQ FoundMatchingDate
    ; The user has left at least one non-day-of-week element open. Step forward through time
    ; until we find a date matching the day-of-month and month specified, if any. Note that
    ; because the year is open, this will interpret a partial specification of "March" as
    ; "March 2022" if it's currently April 2021.
    ;
    ; Temporarily set prv2Flags so IncrementPrvDateOpenElements will treat everything as open.
    ; (Note that it doesn't touch day-of-week anyway, so it's irrelevant that we set that to be
    ; non-open here.) SFTODO: I *think* we need to do this because otherwise a partial
    ; specification like "17th" would never be able to match if today is "15th" (and thus the
    ; initial prvDateMonth is 15).
    LDA prv2Flags:STA prvTmp6:LDA #NOT(prv2FlagDayOfWeek) AND prv2FlagMask:STA prv2Flags
.IncLoop
    LDA prv2DateDayOfMonth
    CMP #&FF:BEQ prvDayOfMonthMatchesFixed
    CMP prvDateDayOfMonth:BNE prvDateDoesntMatchFixed
.prvDayOfMonthMatchesFixed
    LDA prv2DateMonth
    CMP #&FF:BEQ prvDateMatchesFixed
    CMP prvDateMonth:BEQ prvDateMatchesFixed
.prvDateDoesntMatchFixed
    JSR IncrementPrvDateOpenElements:BCC IncLoop
    ; We've looped round incrementing prvDate* as much as we can and we failed to find a
    ; matching date.
    LDA prvTmp6:STA prv2Flags ; restore original prv2Flags
    SEC ; SQUASH: redundant (we didn't BCC just above)
    RTS

.prvDateMatchesFixed
    LDA prvTmp6:STA prv2Flags ; SFTODO: RESTORE STASHED prv2Flags FROM ABOVE?
.FoundMatchingDate
    JSR calculateDayOfWeekInA:STA prvDateDayOfWeek
    ; SFTODO: Speculation but I think correct: At this point prvDate is a concrete date which
    ; is the earliest possible candidate matching the user's partial date specification. We
    ; will later compare it against the user's question and move it forwards in time to see if
    ; we can find a date matching the user's specification completely.
    LDA #0:STA prvDateSFTODOQ ; SFTODO: PROB CORRECT TO USE SFTODOQ BUT NOT 100% SURE
    CLC
    RTS
}

;SFTODOWIP
{
.^LAFF9
    XASSERT_USE_PRV1

    ; Copy prvDate{Century,Year,Month,DayOfMonth,DayOfWeek} to prv2{...} SFTODO: I suspect we
    ; do this because we want to retain the original user partial date specification as we will
    ; in the answers in prvDate*, which is where we will print the final answer from
    LDX #4
.CopyLoop
    LDA prvDateCentury,X:STA prv2DateCentury,X
    DEX:BPL CopyLoop

    ; Set prv2Flags so b4-0 are set iff prv{Century,Year,Month,DayOfMonth,DayOfWeek}
    ; respectively is &FF (open).
    LDX #0
    STX prv2Flags
.SetFlagsLoop
    LDA prvDateCentury,X:CMP #&FF:ROL prv2Flags
    INX:CPX #5:BNE SetFlagsLoop

    ; SFTODO: HIGH LEVEL COMMENT(S)
    JSR SFTODOProbDefaultMissingDateBitsAndCalculateDayOfWeek:BCS BadDate3
    LDA prv2DateDayOfWeek:CMP #&FF:BNE DayOfWeekNotOpen
    JSR ValidateDateTimeRespectingLeapYears
    LDA prvDateSFTODOQ
    AND #prvDateSFTODOQCenturyYearMonthDayOfMonth
    BNE BadDate3
    CLC
    RTS

.BadDate3
    BIT Rts ; set V
    SEC
.Rts
    RTS

.DayOfWeekNotOpen ; SFTODO: I think this code is adjusting the date we've calculated up until now to satisfy user conditions like "last Tuesday in X" or whatever, but I am guessing - however, I chose this label because we come here if the prv2 *copy* of the user's initial inputs lacks the day of week
    CMP #&07:BCC LB03E
    CMP #&5B:BCC LB086 ; SFTODO: maybe one of the "before/after day of week" type queries???
    JMP LB0F3 ; SQUASH: BCS always SFTODO: ditto???

; SFTODO: *Maybe* the case where we want a specific day of week!? Pure guesswork - starting to look very much like it, though fine details still not clear
.LB03E
    LDA prv2Flags:AND #prv2FlagYear OR prv2FlagMonth OR prv2FlagDayOfMonth:BNE SomeOfPrvYearMonthDayOfMonthOpen
    JSR ValidateDateTimeRespectingLeapYears
    LDA prvDateSFTODOQ:AND #prvDateSFTODOQCenturyYearMonthDayOfMonth:BNE BadDate2
.SomeOfPrvYearMonthDayOfMonthOpen
    INC prv2DateDayOfWeek
.SFTODOLOOP
    LDA prv2DateDayOfWeek:CMP prvDateDayOfWeek:BEQ LB071
.SFTODOLOOP2
    JSR IncrementPrvDateOpenElements:BCS BadDate2
    BVC YearNotIncremented
    ; IncrementPrvDateOpenElements has just incremented the year; this is only OK if it's open.
    LDA #prv2FlagYear:BIT prv2Flags:BEQ YearNotOpen ; SFTODO: RENAME BEQ LABEL AS SOME SORT OF "FAIL"???
.YearNotIncremented
    JSR calculateDayOfWeekInA:STA prvDateDayOfWeek
    JMP SFTODOLOOP ; SFTODO: Looks like we're looping round, and IncrementPrvDateOpenElements at least sometimes increments day of month, so I wonder if this is implementing one of the "search for date where day of week is X" operations - maybe
.LB071
    JSR ValidateDateTimeRespectingLeapYears
    LDA prvDateSFTODOQ:AND #prvDateSFTODOQCenturyYearMonthDayOfMonth:BNE SFTODOLOOP2
.LB07B
    CLV
    CLC
    RTS

; SFTODO: As elsewhere, do we really need so many copies of this and similar code fragments? (We might, but check.)
.BadDate2
    SEC
    BIT Rts2
.Rts2
    RTS

.YearNotOpen
    CLV
    SEC
    RTS
			
.LB086
    STA prvA
    LDA #0:STA prvB
    LDA #7:STA prvC
    JSR SFTODOPSEUDODIV ; SFTODO: WILL ALWAYS DIVIDE WITH NO WEIRDNESS
    TAX
    INX
    STX prvDateDayOfWeek
    LDA #prv2FlagCentury OR prv2FlagYear OR prv2FlagMonth OR prv2FlagDayOfMonth:STA prv2Flags
    LDX prvD
    CPX #10:BEQ LB0E7
    CPX #11:BEQ LB0CD
    CPX #12:BEQ LB0DA
    TXA
    PHA
.LB0B1
    JSR calculateDayOfWeekInA:CMP prvDateDayOfWeek:BEQ LB0C1
    JSR IncrementPrvDateOpenElements:BCC LB0B1
    PLA:BCS BadDate2
.LB0C1
    PLA
    TAX
.LB0C3
    DEX
    BEQ LB07B
    JSR IncrementPrvDateOpenElementsByOneWeek
    BCC LB0C3
    CLV
    RTS

.LB0CD
    JSR IncrementPrvDateOpenElements
    JSR calculateDayOfWeekInA
    CMP prvDateDayOfWeek
    BNE LB0CD
    BEQ LB07B ; always branch
.LB0DA
    JSR DecrementPrvDateBy1
    JSR calculateDayOfWeekInA
    CMP prvDateDayOfWeek
    BNE LB0DA
    BEQ LB07B ; always branch
.LB0E7
    JSR calculateDayOfWeekInA
    CMP prvDateDayOfWeek
    BEQ LB07B
    BCS LB0DA
    BCC LB0CD ; always branch

.LB0F3
    LDA #prv2FlagCentury OR prv2FlagYear OR prv2FlagMonth OR prv2FlagDayOfMonth:STA prv2Flags
    LDA prv2DateDayOfWeek
    CMP #&9B:BCC LB116
    SBC #&9A
    TAX
.LB102
    JSR IncrementPrvDateOpenElements
    BCC LB10A
    JMP BadDate2 ; SQUASH: BCS always?
			
.LB10A
    DEX
    BNE LB102
    JSR calculateDayOfWeekInA
    STA prvDateDayOfWeek
    JMP LB07B
			
.LB116
    SEC:SBC #&5A
    TAX
.LB11A
    JSR DecrementPrvDateBy1
    BCC LB122
    JMP BadDate2 ; SQUASH: BCS always?
			
.LB122
    DEX:BNE LB11A
    JSR calculateDayOfWeekInA
    STA prvDateDayOfWeek
    JMP LB07B

.^BadDate
    SEC
    BIT Rts3
.Rts3
    RTS
}

;SFTODOWIP
; This subroutine implements the date calculation features of the *DATE and *CALENDAR commands.
; The calculation to perform is parsed from the command line using (transientCmdPtr),Y.
; On entry, SFTODO!
; On exit, C is clear iff the calculation succeeded. If C is set, V set indicates "Bad date", V clear indicates "Mismatch".
.DateCalculation
{
    XASSERT_USE_PRV1

    ; Set prvDate* up so all the date-related entries (we don't care about time here) are &FF,
    ; indicating they are "open". As we parse the user input we will fill in some or all of
    ; those date-related entries, forming a template date.
    LDX #4
    LDA #&FF
.SetOpenLoop
    STA prvDateCentury,X
    DEX:BPL SetOpenLoop

    ; If there's nothing on the command line, the date is fully open and we're done parsing.
    JSR FindNextCharAfterSpace:LDA (transientCmdPtr),Y:CMP #vduCr:BEQ DateArgumentParsed
    ; Otherwise parse the command line and fill in prvDate* accordingly.
    JSR SFTODOProbParsePlusMinusDate:BCS BadDate:STA prvDateDayOfWeek
    CMP #&FF:BEQ DayOfWeekOpen
    ; The user has specified a day of the week; if there's no trailing comma this is the end of
    ; the user-specified partial date.
    JSR FindNextCharAfterSpace:LDA (transientCmdPtr),Y:CMP #',':BNE DateArgumentParsed
    INY ; skip ','
.DayOfWeekOpen
    JSR ConvertIntegerDefaultDecimal:BCC DayOfMonthInA
    LDA #&FF ; day of month is open
.DayOfMonthInA
    STA prvDateDayOfMonth
    ; After the day of the month there may be a '/' followed by month/year components; if
    ; there's no '/' we have finished parsing the user-specified partial date.
    JSR FindNextCharAfterSpace:LDA (transientCmdPtr),Y:CMP #'/':BNE DateArgumentParsed
    INY ; skip '/'
    JSR ConvertIntegerDefaultDecimal:BCC MonthInA
    LDA #&FF ; month is open
.MonthInA
    STA prvDateMonth
    ; After the month there may be a '/' followed by a year component; if there's no '/' we have finished parsing the user-specified partial date.
    JSR FindNextCharAfterSpace:LDA (transientCmdPtr),Y:CMP #'/':BNE DateArgumentParsed
    INY ; skip '/'
    JSR ConvertIntegerDefaultDecimal:BCC ParsedYearOK
    LDA #&FF:STA prvDateYear:STA prvDateCentury ; century/year are open
    JMP DateArgumentParsed ; SQUASH: BNE always branch
.ParsedYearOK
    JSR InterpretParsedYear
.DateArgumentParsed

    ; Validate the non-open components of prvDate*.
    JSR ValidateDateTimeAssumingLeapYear ; SFTODO: *just possibly* it would be better to validate *respecting* leap year *iff* prvDateYear/prvDateCentury are not &FF (i.e. we have a specific year) - but I could very easily be missing some subtlety here - note that in LAFF9 we redo the validation respecting leap year after filling in the blanks, so this is probably *not* a helpful tweak here - OK, LAFF9 will *sometimes* redo the validation, so just maybe (it's all very unclear right now) this tweak would add a tiny bit of value
    ; Stash the date validation result (shifted into the low nybble) on the stack.
    LDA prvDateSFTODOQ
    LSR A:LSR A:LSR A:LSR A ; SQUASH: JSR LsrA4
    PHA
    ; SFTODO: I believe the use of prvDateSFTODO0 (==prvDateSFTODOQ) here is entirely local to this subroutine - once we call LAFF9 we will not use the value left in there, and will overwrite it most of the time.
    ; Set prvDateSFTODO0 so b3-0 are set iff prvDate{Century,Year,Month,DayOfMonth} is &FF (open).
    LDX #0
    STX prvDateSFTODO0
.Loop
    LDA prvDateCentury,X:CMP #&FF:ROL prvDateSFTODO0
    INX:CPX #4:BNE Loop
    ; Invert prvDateSFTODO0 b0-3, so b3-0 are set iff prvDate{Century,Year,Month,DayOfMonth} is not &FF (open). SFTODO: I THINK I MAY HAVE HAD THE SENSE OF THIS THE WRONG WAY ROUND IN SOME OF MY CODE ANALYSIS
    LDA prvDateSFTODO0:EOR #&0F:STA prvDateSFTODO0
    ; AND prvDateSFTODO0 with the date validation mask we stacked earlier; this will ignore
    ; validation errors where the corresponding date element is open.
    PLA
    AND prvDateSFTODO0
    AND #&0F ; SQUASH: redundant? the value we just pulled with PLA had undergone 4xLSR A so high nybble was already 0
    BNE BadDateIndirect

    ; SFTODO: PROPER COMMENT - "NOW DO WHATEVER LAFF9 DOES"!
    JMP LAFF9

.BadDateIndirect
    JMP BadDate
}

; Take the parsed 2-byte integer year at CovnertIntegerResult and populate
; prvDate{Year,Century}, defaulting the century to the current century if a two digit year is
; specified.
.InterpretParsedYear
{
    XASSERT_USE_PRV1
    LDA ConvertIntegerResult:STA prvA
    LDA ConvertIntegerResult + 1:STA prvB
    LDA #100:STA prvC
    JSR SFTODOPSEUDODIV ; SFTODO: IN PRACTICE THIS WILL ALWAYS DO DIVISION WITH NO WEIRDNESS (9999 WOULD GIVE PRVB=39<100)
    STA prvDateYear
    LDA prvD:BNE CenturyInA
.^GetUserRegCentury
    LDX #userRegCentury:JSR ReadUserReg
.CenturyInA
    STA prvDateCentury
    RTS
}

; SFTODO: This seems to be parsing the "+"/"-" support for *DATE/*CALENDAR and returning with the offset in some form in A (&FF meaning not present/couldn't parse or something like that), probably returns with C clear iff parsed OK. - I think as a whole it's parsing +/- a number of days, a specific day of the week or the +/-day-of-week stuff - this is *probably* why A seems to get shifted round, as I think all this different functionality is mapped into A on return, but not sure
; SFTODO: This has only one caller
; SFTODO: Note the flags reflect A on exit.
.SFTODOProbParsePlusMinusDate
{
SpecificDayOfWeekFlag = transientDateSFTODO1
DayOfWeekSuffix = prvTmp5
OriginalY = prvTmp2

    XASSERT_USE_PRV1
    STY OriginalY
    LDA #0:STA SpecificDayOfWeekFlag
    JSR FindNextCharAfterSpace:LDA (transientCmdPtr),Y
    CMP #'+':BEQ Plus
    CMP #'-':BNE NotPlusOrMinus
    ; SQUASH: Similar chunk of code here and at .plus, could we factor out?
    INY ; skip '-'
    JSR ConvertIntegerDefaultDecimal:BCS NoIntegerParsed1
    CMP #0:BNE PositiveIntegerParsed1 ; SQUASH: "CMP #0" is redundant, flags should reflect A already
.NoIntegerParsed1
    LDA #1
.PositiveIntegerParsed1
    CMP #63+2 ; SFTODO: user guide says 63 is max value, not sure why +2 instead of +1 (+1 make sense as we bcs == branch-if-greater-or-equal)
    BCS OutOfRange
    ADC #&5A ; SFTODO!?
    CLC
    RTS
			
.Plus
    INY ; skip '+'
    JSR ConvertIntegerDefaultDecimal:BCS NoIntegerParsed2
    CMP #0:BNE PositiveIntegerParsed2 ; SQUASH: "CMP #0" is redundant, flags should reflect A already
.NoIntegerParsed2
    LDA #1
.PositiveIntegerParsed2
    CMP #99+2 ; SFTODO: user guide says 99 is max value, as above not sure why +2 instead of +1
    BCS OutOfRange
    ADC #&9A ; SFTODO!?
    CLC
    RTS

.OutOfRange
    LDA #&FF
    SEC
    RTS

; SFTODO: It looks like this is parsing a day name from the command line, returning with A populated and C clear if parsed OK, otherwise returning with A=&FF and C set.
.NotPlusOrMinus
CurrentDayNumber = prvTmp4
StartIndex = prvTmp3
EndIndex = transientDateSFTODO2 ; exclusive
    LDX #0
.DayNameLoop
    STX CurrentDayNumber
    LDA DayMonthNameOffsetTable+1,X:STA EndIndex
    LDA DayMonthNameOffsetTable,X:STA StartIndex
    TAX
.CheckDayNameLoop
    LDA (transientCmdPtr),Y:ORA #LowerCaseMask
    CMP DayMonthNames,X:BNE NotExactlyThisDayName
    INY
    INX:CPX EndIndex:BEQ DayNameMatched
    BNE CheckDayNameLoop ; always branch
.NotExactlyThisDayName
    ; We failed to match exactly, but if we matched at least 2 characters that's OK.
    SEC:TXA:SBC StartIndex:CMP #2:BCS DayNameMatched
    ; We didn't match, so loop round to try another day if there is one.
    LDY OriginalY
    LDX CurrentDayNumber
    INX:CPX #daysPerWeek + 1:BCC DayNameLoop ; +1 as DayMonthNameOffsetTable has "today" as well
    ; We didn't match anything. Note that this isn't an error; we return with C clear.
    LDY OriginalY
    LDA #&FF ; day of week is open
    CLC
    RTS

; SFTODO: This bit looks like it's probably checking for +/- *after* a day name (e.g. "*DATE TU+,23/10/19")
.DayNameMatched
    LDA CurrentDayNumber:BNE SpecificDayOfWeek
    ; The user specified "today" rather than a specific day of the week, so convert that into
    ; the current day of the week.
    LDX #rtcRegDayOfWeek:JSR ReadRtcRam:STA CurrentDayNumber
    LDA #&FF:STA SpecificDayOfWeekFlag ; SQUASH: Just DEC SpecificDayOfWeekFlag?
.SpecificDayOfWeek
    ; Now set DayOfWeekSuffix to reflect the suffix (+, -, *, 1-9) or lack of suffix.
    LDX #0
    LDA (transientCmdPtr),Y
    CMP #'+':BNE LB285
    LDX #&0B
.LB285
    CMP #'-':BNE LB28B
    LDX #&0C
.LB28B
    CMP #'*':BNE LB291
    LDX #&0A
.LB291
    CMP #'1':BCC LB29C
    CMP #'9'+1:BCS LB29C
    AND #&0F:TAX
.LB29C
    CPX #0:BEQ NoSuffixParsed
    INY ; skip the suffix we parsed
.NoSuffixParsed
    DEC CurrentDayNumber ; make CurrentDayNumber 0-based instead of 1-based
    STX DayOfWeekSuffix
    ; SFTODO: Pack the parsed details into A in some currently unclear way.
    TXA
    ASL A
    ASL A
    ASL A
    SEC
    SBC DayOfWeekSuffix
    CLC
    ADC CurrentDayNumber
    CLC
    RTS
}

; Parse a time from the command line, populating prvDate* and returning with C clear iff parsing succeeds.
.ParseAndValidateTime
{
    XASSERT_USE_PRV1
    JSR ConvertIntegerDefaultDecimal:BCS ParseError:STA prvDateHours
    LDA (transientCmdPtr),Y:INY
    CMP #':':BNE ParseError
    JSR ConvertIntegerDefaultDecimal:BCS ParseError:STA prvDateMinutes
    LDA (transientCmdPtr),Y
    CMP #':':BEQ SkipCharAndParseSeconds
    CMP #'/':BEQ SkipCharAndParseSeconds
    LDA #0 ; default to 0 seconds if not specified
    BEQ SecondsInA ; always branch
.SkipCharAndParseSeconds
    INY
    JSR ConvertIntegerDefaultDecimal:BCS ParseError
.SecondsInA
    STA prvDateSeconds
    TYA:PHA:JSR ValidateDateTimeAssumingLeapYear:PLA:TAY
    LDA prvDateSFTODOQ:AND #prvDateSFTODOQHoursMinutesSeconds:BNE ParseError
    CLC
    RTS
			
.ParseError
    SEC
    RTS
}

; Parse a date from the command line, populating PrvDate* and returning with C clear iff parsing succeeds.
; SQUASH: This has only one caller
.ParseAndValidateDate
{
    XASSERT_USE_PRV1
    LDA #0:STA prvDateDayOfWeek
    JSR ConvertIntegerDefaultDecimal:BCS ParseError:STA prvDateDayOfMonth
    LDA (transientCmdPtr),Y:INY
    CMP #'/':BNE ParseError
    JSR ConvertIntegerDefaultDecimal:BCS ParseError:STA prvDateMonth
    LDA (transientCmdPtr),Y:INY
    CMP #'/':BNE ParseError
    JSR ConvertIntegerDefaultDecimal:BCS ParseError:JSR InterpretParsedYear
    JSR ValidateDateTimeAssumingLeapYear
    LDA prvDateSFTODOQ:AND #prvDateSFTODOQCenturyYearMonthDayOfMonth:BNE ParseError
    JSR calculateDayOfWeekInPrvDateDayOfWeek
    CLC
    RTS
			
.ParseError
    SEC
    RTS
}

; Alarm interrupt handler code.
;
; At the hardware level, the alarm seems to be handled by setting the rtcRegBAIE (alarm
; interrupt enable) bit and clearing the rtcRegBPIE (periodic interrupt enable) bit to start
; with. When the alarm interrupt occurs and RtcInterruptHandler acknowledges the interrupts,
; AlarmInterruptHandler will set the PIE bit to cause periodic interrupts so we can continue
; to receive interrupts until the alarm as a user-visible event is over.
{
OswordSoundBlockCopy = TransientZP

; Return with N set iff Ctrl is pressed and V set iff Shift is pressed.
.TestShiftCtrl
    CLV:CLC:JMP (KEYVL)

.OswordSoundBlock
    EQUW   3 ; channel
OswordSoundAmplitudeOffset = P% - OswordSoundBlock
    EQUW -15 ; amplitude
OswordSoundPitchOffset = P% - OswordSoundBlock
    EQUW 210 ; pitch
    EQUW   5 ; duration
OswordSoundBlockSize = P% - OswordSoundBlock

; Each "duration unit" corresponds to two interrupts from the RTC (two not one because on every
; other interrupt we only execute the code at JustToggleLeds). The values programmed into RV*
; and RS* of RTC register A presumably determine the frequency and mark/space cycle of these
; interrupts.
.AlarmOverallDurationLookup
    EQUB 2, 8
.AlarmAudioDurationLookup
    EQUB 15, 30, 60, 120
.AlarmAmplitudeLookup
    EQUB -10 AND &FF:EQUB -15 AND &FF
.AlarmPitchLookup
    EQUB 90, 130, 176, 210

.CapsLockLookup
    EQUB addressableLatchCapsLock OR addressableLatchData0
    EQUB addressableLatchCapsLock OR addressableLatchData1
.ShiftLockLookup
    EQUB addressableLatchShiftLock OR addressableLatchData1
    EQUB addressableLatchShiftLock OR addressableLatchData0

.^AlarmInterruptHandler ; entered with C set
    ; Set bit 6 of userRegAlarm to be a copy of bit 7, i.e. copy userRegAlarmRepeatBit into
    ; userRegAlarmEnableBit, so the alarm remains enabled iff it is in repeating mode.
    ASSERT userRegAlarmRepeatBit == 1<<7
    ASSERT userRegAlarmEnableBit == 1<<6
    LDX #userRegAlarm:JSR ReadUserReg
    ASL A:PHP
    ASL A:PLP:PHP:ROR A
    PLP:ROR A
    JSR WriteUserReg
.^osbyte49FE
    SEC
.^PeriodicInterruptHandler ; entered with C clear
    XASSERT_USE_PRV1
    LDA romselCopy:PHA
    LDA ramselCopy:PHA
    ; SFTODO: How are we called? Do we need to do this romsel/ramsel stuff or will our caller have done it already?
    AND #ramselShen:ORA #ramselPrvs1:STA ramselCopy:STA ramsel
    ; SQUASH: Can we do the next line above to save redoing LDA romselCopy?
    LDA romselCopy:ORA #romselPrvEn:STA romselCopy:STA romsel
    BCC HandlingPeriodicInterrupt
    ; This isn't a periodic interrupt, so perform some initialisation which will apply to this
    ; alarm interrupt and subsequent periodic interrupts until the alarm (as a user event) is
    ; finished.
    LDX #userRegAlarm:JSR ReadUserReg
    ; Shift userRegAlarm in A right as we extract the bitfields and use them to control
    ; initialisation.
    PHA
    AND #1:TAX:LDA AlarmOverallDurationLookup,X:STA prvAlarmOverallDuration
    PLA:LSR A:PHA
    AND #%11:TAX:LDA AlarmAudioDurationLookup,X:STA prvAlarmAudioDuration
    PLA:LSR A:LSR A:PHA
    AND #%11:TAX:LDA AlarmPitchLookup,X:STA prvAlarmPitch
    PLA:LSR A:LSR A
    AND #1:TAX:LDA AlarmAmplitudeLookup,X:STA prvAlarmAmplitude
    ; Force RTC register A ARS3/2/1 on and ARS0 off.
    LDX #rtcRegA:JSR ReadRtcRam
    AND_NOT rtcRegARS3 OR rtcRegARS2 OR rtcRegARS1 OR rtcRegARS0
    ORA #rtcRegARS3 OR rtcRegARS2 OR rtcRegARS1
    JSR WriteRtcRam
    ; Force RTC register B PIE (periodic interrupt enable) on.
    LDX #rtcRegB:JSR ReadRtcRam:ORA #rtcRegBPIE:JSR WriteRtcRam
    LDA #1:STA prvAlarmToggle
    ; Now continue to do the periodic interrupt processing for the first time.

.HandlingPeriodicInterrupt
    ; Toggle prvAlarmToggle; if it's 0 we just toggle the LEDs and don't make a sound, test the
    ; keyboard or decrement the duration counters.
    LDA prvAlarmToggle:EOR #1:STA prvAlarmToggle:BEQ JustToggleLeds
    LDA prvAlarmAudioDuration:BEQ AlarmAudioDurationExpired

    ; Make a sound using OSWORD 7.
    ; SQUASH: Couldn't we use some private RAM to hold the OSWORD 7 block? The OS is executing
    ; OSWORD 7 - we're using a standard sound channel, not something fancy - and can see
    ; sideways RAM just fine. That way we could avoid the save/restore overhead.
    LDY #OswordSoundBlockSize - 1
.SoundBlockCopySaveLoop
    LDA OswordSoundBlockCopy,Y:PHA
    DEY:BPL SoundBlockCopySaveLoop
    LDY #OswordSoundBlockSize - 1
.SoundBlockCopyLoop
    LDA OswordSoundBlock,Y:STA OswordSoundBlockCopy,Y
    DEY:BPL SoundBlockCopyLoop
    LDA prvAlarmAmplitude:STA OswordSoundBlockCopy + OswordSoundAmplitudeOffset
    LDA prvAlarmPitch:STA OswordSoundBlockCopy + OswordSoundPitchOffset
    LDA #oswordSound:LDX #lo(OswordSoundBlockCopy):LDY #hi(OswordSoundBlockCopy):JSR OSWORD
    LDY #0
.SoundBlockCopyRestoreLoop
    PLA:STA OswordSoundBlockCopy,Y
    INY:CPY #OswordSoundBlockSize:BNE SoundBlockCopyRestoreLoop

    DEC prvAlarmAudioDuration
.AlarmAudioDurationExpired
    LDA prvAlarmOverallDuration:BNE AlarmOverallDurationNotExpired
    JSR TestShiftCtrl:BVC NotShiftAndCtrlPressed:BPL NotShiftAndCtrlPressed
    ; The alarm event is finishing, either because the user presed Ctrl-Shift to acknowledge it
    ; or its overall duration has elapsed.
    ; Force RTC register B PIE off and set AIE iff userRegAlarmEnableBit is set.
    ASSERT userRegAlarmEnableBit >> 1 == rtcRegBAIE
    LDX #userRegAlarm:JSR ReadUserReg:LSR A:AND #rtcRegBAIE:STA prvAlarmTmp
    LDX #rtcRegB:JSR ReadRtcRam
    AND_NOT rtcRegBPIE OR rtcRegBAIE:ORA prvAlarmTmp:JSR WriteRtcRam
    ; Force RTC register A ARS3/2/1/0 off.
    LDX #rtcRegA:JSR ReadRtcRam
    AND_NOT rtcRegARS3 OR rtcRegARS2 OR rtcRegARS1 OR rtcRegARS0:JSR WriteRtcRam
    ; Set the keyboard LEDs up to reflect the real state again.
    LDA #osbyteReflectKeyboardStatusInLeds:JSR OSBYTE
    JMP RestoreRamselRomselAndExit
			
.AlarmOverallDurationNotExpired
    DEC prvAlarmOverallDuration
.NotShiftAndCtrlPressed
.JustToggleLeds
    ; prvAlarmToggle is 0 or 1 here; as we toggle between those two values over multiple
    ; calls to this code we alternate which of the Shift and Caps Lock LEDs is lit.
    LDX prvAlarmToggle
    LDA SHEILA + systemViaBase + viaRegisterB
    AND_NOT addressableLatchMask:ORA CapsLockLookup,X
    STA SHEILA + systemViaBase + viaRegisterB
    LDA SHEILA + systemViaBase + viaRegisterB
    AND_NOT addressableLatchMask:ORA ShiftLockLookup,X
    STA SHEILA + systemViaBase + viaRegisterB

.RestoreRamselRomselAndExit
    PLA:STA ramselCopy:STA ramsel
    PLA:STA romselCopy:STA romsel
    RTS
}

; On entry, X=rtcRegC and A is the value read from rtcRegC.
.RtcInterruptHandler
{
    DEX:ASSERT rtcRegC - 1 == rtcRegB
    JSR Nop3:STX rtcAddress
    JSR Nop3:AND rtcData
    ; We now have A = (RTC register B) AND (RTC register C); this means we have bits set in A
    ; for interrupts which have triggered and are not masked off. I believe this read from
    ; register C will also acknowledge and clear these interrupts. We shift A left and test the
    ; bits as they fall off into the carry.
    ; SFTODO: As far as I can see, SeiSelectRtcAddressXVariant will disable interrupts and
    ; nothing will re-enable them. Am I missing something? Is this correct behaviour?
    JSR SeiSelectRtcAddressXVariant
    ASL A:ASL A:BCC NoPeriodicInterrupt
    PHA
    CLC:JSR PeriodicInterruptHandler
    PLA
.NoPeriodicInterrupt
    ASL A:BCC NoAlarmInterrupt
    PHA
    JSR AlarmInterruptHandler
    PLA
.NoAlarmInterrupt
    ASL A:BCC NoUpdateEndedInterrupt
    ; DELETE: Is the support for notifying user code of update ended interrupts really useful?
    ; Access to the RTC via OSBYTE calls will automatically wait for updates to pass, and any
    ; code dealing directly with the RTC chip could just wait for updates to pass itself.
    LDX #prvRtcUpdateEndedOptions - prv83:JSR ReadPrivateRam8300X
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

.PrvDisGenerateMismatch
    PRVDIS
    JSR RaiseError
    EQUB &80
    EQUS "Mismatch", &00

.PrvDisGenerateBadDate
    PRVDIS
    JSR RaiseError
    EQUB &80
    EQUS "Bad date", &00

.PrvDisGenerateBadTime
    PRVDIS
    JSR RaiseError
    EQUB &80
    EQUS "Bad time", &00

;*TIME Command
.time
{
    PRVEN
    LDA (transientCmdPtr),Y:CMP #'=':BEQ SetTime
    JSR InitDateSFTODOS
    LDA #&FF:STA prvDateSFTODO7:STA prvDateSFTODO6
    LDA #lo(prvDateBuffer):STA prvDateSFTODO4:LDA #hi(prvDateBuffer):STA prvDateSFTODO4 + 1
    JSR CopyRtcDateTimeToPrv
    JSR InitDateBufferAndEmitTimeAndDate
    JSR PrintDateBuffer
.PrvDisExitAndClaimServiceCall
    PRVDIS
    JMP ExitAndClaimServiceCall

.SetTime
    INY ; skip '='
    JSR ParseAndValidateTime:BCC ParsedOk ; SQUASH: BCS PrvDisGenerateBadTime then fall through
    JMP PrvDisGenerateBadTime
.ParsedOk
    JSR CopyPrvTimeToRtc
    JMP PrvDisExitAndClaimServiceCall
}

;*DATE Command
.date
{
    PRVEN
    LDA (transientCmdPtr),Y:CMP #'=':BEQ SetDate
    JSR InitDateSFTODOS
    LDA prvDateSFTODO2:AND #&F0:STA prvDateSFTODO2 ; SQUASH: It would be shorter just to do LDA #xx:STA prvDateSFTODO2
    JSR DateCalculation
    BCC CalculationOk
    BVS PrvDisGenerateBadDateIndirect
    JMP PrvDisGenerateMismatch
.PrvDisGenerateBadDateIndirect
    JMP PrvDisGenerateBadDate
.CalculationOk
    LDA #lo(prvDateBuffer):STA prvDateSFTODO4:LDA #hi(prvDateBuffer):STA prvDateSFTODO4 + 1
    JSR InitDateBufferAndEmitTimeAndDate
    JSR PrintDateBuffer
.PrvDisExitAndClaimServiceCall
    PRVDIS
    JMP ExitAndClaimServiceCall

.SetDate
    INY ; skip '='
    JSR ParseAndValidateDate:BCC ParsedOk ; SQUASH: BCS PrvDisGenerateBadDate
    JMP PrvDisGenerateBadDate
.ParsedOk
    JSR CopyPrvDateToRtc
    JMP PrvDisExitAndClaimServiceCall
}
			
;Start of CALENDAR * Command
.calend
{
DayOfWeek = prvA ; this is also the row number
CellIndex = prvB ; current element in the 42-element structure generated by generateInternalCalendar
Column = prvC

    PRVEN
    ; SQUASH: Can we share the next few lines of code with *DATE?
    JSR DateCalculation:BCC CalculationOk
    BVS PrvDisGenerateBadDateIndirect
    JMP PrvDisGenerateMismatch
.PrvDisGenerateBadDateIndirect
    JMP PrvDisGenerateBadDate
.CalculationOk
    ; Output the month name and year as the calendar heading.
    LDA #lo(prvDateBuffer2):STA prvDateSFTODO4:LDA #hi(prvDateBuffer2):STA prvDateSFTODO4 + 1
    LDA #&05:STA prvDateSFTODO0 ; SFTODO: Is this used? I suspect it may be used as a return value to a caller via an Integra-B OSWORD but not sure
    LDA #&40:STA prvDateSFTODO1 ; SFTODO: use just a single space as separator between (empty) time and the date?
    LDA #&00:STA prvDateSFTODO2 ; SFTODO: don't emit time? not sure what high nybble means atm
    LDA #&F8:STA prvDateSFTODO3 ; SFTODO: just emit month name (capitalised) and 4-digit year?
    JSR InitDateBufferAndEmitTimeAndDate
    ; Output 23-(transientDateBufferIndex/2) spaces to centre the month name and year with
    ; respect to the calendar.
    SEC:LDA #23:SBC transientDateBufferIndex:LSR A:TAX
    LDA #' '
.SpaceLoop
    JSR OSWRCH
    DEX:BNE SpaceLoop
    LDX #0
.HeadingPrintLoop
    LDA prvDateBuffer2,X:JSR OSASCI
    CMP #vduCr:BEQ HeadingPrinted
    INX:BNE HeadingPrintLoop ; always branch
.HeadingPrinted

    ; Now generate and print the calendar grid, with the day names as row headings.
    JSR generateInternalCalendar
    LDA #1:STA DayOfWeek
    LDA #0:STA CellIndex
.RowLoop
    LDY #0:STY transientDateBufferIndex
    LDA #lo(prvDateBuffer):STA transientDateBufferPtr:LDA #hi(prvDateBuffer):STA transientDateBufferPtr + 1
    ; SQUASH: DayOfWeek is 1-7 here, so do TAY instead of LDY #&FF as we just need a non-0 value.
    LDA DayOfWeek:LDX #3:LDY #&FF:CLC:JSR EmitDayOrMonthName ; emit day name using style "Mon", "Tue", etc
    LDA #0:STA Column ; SQUASH: Use Y=0 from transientDateBufferIndex above to set Column
.ColumnLoop
    LDA #' ':JSR EmitAToDateBuffer
    LDX CellIndex:LDA prvDateBuffer2,X
    LDX #3:JSR emitADecimalFormatted ; emit A with 0 formatted as "  " and 5 as " 5"
    INC CellIndex
    INC Column:LDA Column:CMP #6:BCC ColumnLoop ; SFTODO: prob use one of named constants I plan to introduce in generateInternalCalendar
    LDA #vduCr:JSR EmitAToDateBuffer
    LDX #0
.PrintLineLoop
    LDA prvDateBuffer,X:JSR OSASCI
    CMP #vduCr:BEQ PrintLineDone
    INX:BNE PrintLineLoop ; always branch
.PrintLineDone
    INC DayOfWeek
    LDA DayOfWeek
    CMP #daysPerWeek + 1
    BCC RowLoop
    PRVDIS
    JMP ExitAndClaimServiceCall
}

{
; We enter here with C clear when we see "=" on the command line.
.SetAlarm
    INY
; We enter here with C set if we didn't see "=" but couldn't parse anything else so are trying
; to parse this as an alarm set operation anyway.
.TryParsingAsSetAlarm
    PHP
    JSR ParseAndValidateTime:BCC ParsedTimeOk
    PLP:BCC PrvDisGenerateBadTimeIndirect ; branch if we saw "=" when parsing command line
    PRVDIS
    JMP GenerateSyntaxErrorForTransientCommandIndex
.PrvDisGenerateBadTimeIndirect
    JMP PrvDisGenerateBadTime

.ParsedTimeOk
    PLP
    JSR CopyPrvAlarmToRtc
    JSR FindNextCharAfterSpace:LDA (transientCmdPtr),Y:AND #CapitaliseMask:CMP #'R'
    PHP:PLA:LSR A:LSR A:PHP:ASSERT flagZ = 1 << 1 ; get Z flag into C and save
    LDX #userRegAlarm:JSR ReadUserReg
    ; Set b7 (userRegAlarmRepeatBit) of userRegAlarm value to saved Z flag, i.e. 1 iff 'R' seen.
    ASSERT userRegAlarmRepeatBit = 1<<7:ASL A:PLP:ROR A
    JMP TurnAlarmOn
			
;*ALARM Command
.^alarm
    PRVEN
    LDA (transientCmdPtr),Y
    CMP #'=':CLC:BEQ SetAlarm
    CMP #'?':BEQ ShowAlarm
    CMP #vduCr:BEQ ShowAlarm
    JSR ParseOnOff:BCS TryParsingAsSetAlarm ; branch if we couldn't parse "ON" or "OFF"
    PHP
    LDX #userRegAlarm:JSR ReadUserReg
    PLP:BNE TurnAlarmOn
    AND_NOT userRegAlarmEnableBit:JSR WriteUserReg
    ; Force PIE (periodic interrupt enable) and AIE (alarm interrupt enable) off.
    LDX #rtcRegB:JSR ReadRtcRam:AND_NOT rtcRegBPIE OR rtcRegBAIE:JSR WriteRtcRam
    JMP Finish
			
.TurnAlarmOn
    ORA #userRegAlarmEnableBit:JSR WriteUserReg
    ; Force PIE (periodic interrupt enable) off and AIE (alarm interrupt enable) on.
    LDX #rtcRegB:JSR ReadRtcRam:AND_NOT rtcRegBPIE OR rtcRegBAIE:ORA #rtcRegBAIE:JSR WriteRtcRam
    JMP Finish
			
.ShowAlarm
    LDA #&40:STA prvDateSFTODO1
    LDA #prvDateSFTODO2UseHours:STA prvDateSFTODO2
    LDA #&00:STA prvDateSFTODO3
    LDA #&FF:STA prvDateSFTODO7:STA prvDateSFTODO6
    LDA #lo(prvDateBuffer):STA prvDateSFTODO4:LDA #hi(prvDateBuffer):STA prvDateSFTODO4 + 1
    JSR CopyRtcAlarmToPrv
    JSR InitDateBufferAndEmitTimeAndDate
    DEC prvDateSFTODO1b:JSR PrintDateBuffer ; DEC chops off trailing vduCr
    LDA #'/':JSR OSWRCH:JSR printSpace
    LDX #rtcRegB:JSR ReadRtcRam:AND #rtcRegBAIE:JSR PrintOnOff
    LDX #userRegAlarm:JSR ReadUserReg:AND #userRegAlarmRepeatBit:BEQ NewlineAndFinish
    JSR printSpace:LDA #'R':JSR OSWRCH
.NewlineAndFinish
    JSR OSNEWL
.Finish
    PRVDIS
    JMP ExitAndClaimServiceCall
}
			
;OSWORD &0E (14) Read real time clock
.osword0e
{
    JSR SaveTransientZP
    PRVEN
    LDA oswdbtX:STA prvOswordBlockOrigAddr
    LDA oswdbtY:STA prvOswordBlockOrigAddr + 1
    JSR oswordsv
    JSR oswd0e_1
    BCS osword0ea
    JSR oswordrs
.osword0ea
    ; Restore original A/X/Y. SQUASH: Do we need to do this? Did we modify them?
    LDA prvOswordBlockOrigAddr:STA oswdbtX
    LDA prvOswordBlockOrigAddr + 1:STA oswdbtY
    LDA #&0E:STA oswdbtA
    PRVDIS
    JMP RestoreTransientZPAndExitAndClaimServiceCall
}
			
;OSWORD &49 (73) - Integra-B calls
{
.^osword49
    JSR SaveTransientZP
    PRVEN
    LDA oswdbtX:STA prvOswordBlockOrigAddr
    LDA oswdbtY:STA prvOswordBlockOrigAddr + 1
    JSR oswordsv ; save the OSWORD block
    JSR oswd49_1 ; execute the OSWORD call
    BCS Success
    JSR oswordrs ; restore the OSWORD block if we failed
.Success
    ; Restore A/X/Y. SQUASH: Will we have modified X/Y?
    LDA prvOswordBlockOrigAddr:STA oswdbtX
    LDA prvOswordBlockOrigAddr + 1:STA oswdbtY
    LDA #&49:STA oswdbtA
    PRVDIS
.^RestoreTransientZPAndExitAndClaimServiceCall
    JSR RestoreTransientZP
    JMP ExitAndClaimServiceCall
}
			
;Save OSWORD XY entry table
{
Ptr = &AE

.^oswordsv ; SFTODO: rename
    XASSERT_USE_PRV1
    LDA prvOswordBlockOrigAddr:STA Ptr
    LDA prvOswordBlockOrigAddr + 1:STA Ptr + 1
    LDY #prvOswordBlockCopySize - 1
.Loop
    LDA (Ptr),Y:STA prvOswordBlockCopy,Y
    DEY:BPL Loop
    RTS
}
			
;Restore OSWORD XY entry table
{
Ptr = &AE

.^oswordrs ; SFTODO: rename
    XASSERT_USE_PRV1
    LDA prvOswordBlockOrigAddr:STA Ptr
    LDA prvOswordBlockOrigAddr + 1:STA Ptr + 1
    LDY #prvOswordBlockCopySize - 1
.Loop
    LDA prvOswordBlockCopy,Y:STA (Ptr),Y
    DEY:BPL Loop
    RTS
}

.ClearPrvOswordBlockCopy
{
    XASSERT_USE_PRV1
    LDY #prvOswordBlockCopySize - 1
    LDA #0
.Loop
    STA prvOswordBlockCopy,Y
    DEY:BPL Loop
    RTS
}
			
;OSWORD &0E (14) Read real time clock XY?0 parameter lookup code
.oswd0e_1
{
    XASSERT_USE_PRV1
    ; Transfer control to the handler at oswd0elu[prvOswordBlockCopy] using RTS.
    LDA prvOswordBlockCopy:ASL A:TAY
    LDA oswd0elu+1,Y:PHA
    LDA oswd0elu,Y:PHA
    RTS

;OSWORD &0E (14) Read real time clock XY?0 parameter lookup table
.oswd0elu
    EQUW oswd0eReadString - 1	; XY?0=0: Read time and date in string format
    EQUW oswd0eReadBCD - 1	; XY?0=1: Read time and date in binary coded decimal (BCD) format
    EQUW oswd0eConvertBCD - 1	; XY?0=2: Convert BCD values into string format
}

;OSWORD &49 (73) - Integra-B calls XY?0 parameter lookup code
; SQUASH: This has only one caller
.oswd49_1 ; SFTODO: rename
{
    XASSERT_USE_PRV1
    ; prvOswordBlockCopy is a code in the range &60-&6F; we use that to index into oswd49lu and
    ; transfer control to the relevant handler via RTS.
    SEC:LDA prvOswordBlockCopy:SBC #&60:ASL A:TAY
    LDA oswd49lu+1,Y:PHA
    LDA oswd49lu,Y:PHA
.Rts
    RTS
			
;OSWORD &49 (73) - Integra-B calls XY?0 parameter lookup table
.oswd49lu
    EQUW LB899-1		;XY?0=&60: Function TBC
    EQUW LB891-1		;XY?0=&61: Function TBC
    EQUW LB89C-1		;XY?0=&62: Function TBC
    EQUW Rts - 1		;XY?0=&63: Function TBC - No function?
    EQUW LB8C6-1		;XY?0=&64: Function TBC
    EQUW LB8D8-1		;XY?0=&65: Function TBC
    EQUW LB8DD-1		;XY?0=&66: Function TBC
    EQUW LB8E2-1		;XY?0=&67: Function TBC
    EQUW LB8AC-1		;XY?0=&68: Function TBC
    EQUW LB8B1-1		;XY?0=&69: Function TBC
    EQUW LB8FC-1		;XY?0=&6A: Function TBC
    EQUW LB901-1		;XY?0=&6B: Function TBC
}

; SFTODO: Mostly un-decoded
; SFTODO: *Roughly* speaking this is copying prvOswordBlockCopy+1 bytes of data from prvDateBuffer to the 32-bit address at prvOswordBlockOrigAddr+4 in a tube-aware way, although we also have the option use b7 of prvOswordBlockCopy+7 to explicitly ignore tube.
.CopyPrvDateBuffer ; SFTODO: probably not ideal name but will do for now
{
Ptr = &A8
AddressOffset = prvDateSFTODO4 - prvOswordBlockCopy

    XASSERT_USE_PRV1
    ; SFTODO: Is the next line technically incorrect? We should probably only write to the host
    ; if the high word is &FFFF, not just if the high bit of the high word is set.
    BIT prvDateSFTODO7:BMI HostWrite
    BIT tubePresenceFlag:BPL HostWrite

    ; Copy into the parasite.
.ClaimLoop
    LDA #tubeEntryClaim + tubeClaimId:JSR tubeEntry:BCC ClaimLoop
    CLC:LDA prvOswordBlockOrigAddr:ADC #lo(AddressOffset):TAX
    LDA prvOswordBlockOrigAddr + 1:ADC #hi(AddressOffset):TAY
    LDA #tubeEntryMultibyteHostToParasite:JSR tubeEntry
    LDY #0
.TubeWriteLoop
    LDA prvDateBuffer,Y
.Full
    BIT tubeReg3Status:BVC Full
    STA tubeReg3Data
    INY:CPY prvDateSFTODO1:BNE TubeWriteLoop
    LDA #tubeEntryRelease + tubeClaimId:JSR tubeEntry
    CLC
    RTS

    ; Copy into the host.
.HostWrite
    ; Make Ptr point to the address at offset 4..5 in the original OSWORD block.
    LDA prvOswordBlockOrigAddr:STA Ptr
    LDA prvOswordBlockOrigAddr + 1:STA Ptr + 1
    LDY #AddressOffset:LDA (Ptr),Y:TAX
    INY:LDA (Ptr),Y:STA Ptr + 1
    STX Ptr
    ; Now copy prvOswordBlockCopy + 1 bytes from FromBase to that address.
    LDY #0
.HostWriteLoop
    LDA prvDateBuffer,Y:STA (Ptr),Y
    INY:CPY prvDateSFTODO1:BNE HostWriteLoop
    CLC
    RTS
}

{
;OSWORD &0E (14) Read real time clock
;XY&0=0: Read time and date in string format
.^oswd0eReadString
    JSR CopyRtcDateTimeToPrv
.^oswd0eReadStringInternal
    XASSERT_USE_PRV1
    JSR InitDateSFTODOS
    LDA prvOswordBlockOrigAddr:STA prvDateSFTODO4
    LDA prvOswordBlockOrigAddr + 1:STA prvDateSFTODO4 + 1
    JSR InitDateBufferAndEmitTimeAndDate
    SEC
    RTS
}

{
;OSWORD &0E (14) Read real time clock
;XY&0=1: Read time and date in binary coded decimal (BCD) format
.^oswd0eReadBCD
   JSR CopyRtcDateTimeToPrv
   LDY #6
.Loop
   JSR ConvertBinaryToBcd:STA (oswdbtX),Y
   DEY:BPL Loop
   SEC
   RTS
}

{
;OSWORD &0E (14) Read real time clock
;XY&0=2: Convert BCD values into string format
.^oswd0eConvertBCD
    XASSERT_USE_PRV1
    LDX #6
.Loop
    LDA prvOswordBlockCopy + 1,X
    JSR ConvertBcdToBinary
    STA prvDateYear,X
    DEX:BPL Loop
    LDA #19:STA prvDateCentury ; ENHANCE: Treat years &00-&79 as 20xx?
    JMP oswd0eReadStringInternal ; SQUASH: "BNE ; always branch"

; Convert binary value (<=99) at prvDateYear,Y to BCD representation in A; prvDateYear,Y is
; corrupted on exit.
; SQUASH: This has only one caller.
.^ConvertBinaryToBcd
    XASSERT_USE_PRV1
    ; SFTODO: Isn't this buggy? If prvDateYear,Y is >=100, we will loop forever. I suspect the
    ; HundredsLoop label should be *after* the LDA prvDateYear,Y. In practice this probably
    ; never happens - we can't generate a valid BCD representation of a value >=100 - but in
    ; that case HundredsLoop up to and including the ADC #100 is redundant.
.HundredsLoop
    LDA prvDateYear,Y
    SEC:SBC #100:BCS HundredsLoop
    ADC #100
    LDX #&FF
    SEC
.TensLoop
    INX:SBC #10:BCS TensLoop
    ADC #10
    ; We now have tens in X and ones in A.
    STA prvDateYear,Y
    TXA
    ASL A:ASL A:ASL A:ASL A
    ORA prvDateYear,Y
    RTS

; Convert A from BCD to binary.
; SQUASH: This has only one caller
.ConvertBcdToBinary
    ; If A on entry is &xy, return with
    ; A = (&x0       >> 1) + (&x0       >> 3) + &y
    ;   = ((&x << 4) >> 1) + ((&x << 4) >> 3) + &y
    ;   = (&x * 8)         + (&x * 2)         + &y
    ;   = (&x * 10)                           + &y
    XASSERT_USE_PRV1
    PHA
    AND #&0F
    STA prvTmp2
    PLA
    AND #&F0
    LSR A
    STA prvTmp3
    LSR A
    LSR A
    CLC
    ADC prvTmp3
    ADC prvTmp2
    RTS
}

;XY?0=&61
;OSWORD &49 (73) - Integra-B calls
.LB891
    JSR ClearPrvOswordBlockCopy
    JSR CopyRtcDateTimeToPrv
    CLC
    RTS
			
;XY?0=&60
;OSWORD &49 (73) - Integra-B calls
.LB899
    JSR CopyRtcDateTimeToPrv
    FALLTHROUGH_TO LB89C

;XY?0=&62
;OSWORD &49 (73) - Integra-B calls
.LB89C
    XASSERT_USE_PRV1
    ; SQUASH: We probably do the next operations a lot and could factor them out.
    LDA #lo(prvDateBuffer):STA prvDateSFTODO4:LDA #hi(prvDateBuffer):STA prvDateSFTODO4 + 1
    JSR InitDateBufferAndEmitTimeAndDate
    JMP CopyPrvDateBuffer ; SQUASH: rearrange and fall through?
			
;XY?0=&68
;OSWORD &49 (73) - Integra-B calls
.LB8AC
    JSR LAFF9
    CLC
    RTS
			
;XY?0=&69
;OSWORD &49 (73) - Integra-B calls
.LB8B1
    XASSERT_USE_PRV1
    LDA #lo(prvDateBuffer):STA prvDateSFTODO4:LDA #hi(prvDateBuffer):STA prvDateSFTODO4 + 1
    JSR generateInternalCalendar
    LDA #42:STA prvDateSFTODO1 ; SFTODO: magic (=42=max size of resulting buffer - see generateInternalCalendar - ?)
    JMP CopyPrvDateBuffer
			
;XY?0=&64
;OSWORD &49 (73) - Integra-B calls
.LB8C6
    XASSERT_USE_PRV1
    JSR ClearPrvOswordBlockCopy
    JSR CopyRtcAlarmToPrv
    LDX #rtcRegB:JSR ReadRtcRam
    AND #rtcRegBPIE OR rtcRegBAIE
    STA prvOswordBlockCopy + 1 ; SFTODO: Alternate label?
    CLC
    RTS

; SFTODO: Don't these next two calls contain most of the logic we'd need to implement OSWORD &F?
;XY?0=&65
;OSWORD &49 (73) - Integra-B calls
.LB8D8
    JSR CopyPrvTimeToRtc
    SEC
    RTS
			
;XY?0=&66
;OSWORD &49 (73) - Integra-B calls
.LB8DD
    JSR CopyPrvDateToRtc
    SEC
    RTS
			
;XY?0=&67
;OSWORD &49 (73) - Integra-B calls
.LB8E2
    XASSERT_USE_PRV1
    JSR CopyPrvAlarmToRtc
    LDA prvOswordBlockCopy + 1:AND #rtcRegBPIE OR rtcRegBAIE:STA prvOswordBlockCopy + 1
    LDX #rtcRegB:JSR ReadRtcRam
    AND_NOT rtcRegBPIE OR rtcRegBAIE
    ORA prvOswordBlockCopy + 1
    JSR WriteRtcRam
    SEC
    RTS

;XY?0=&6A
;OSWORD &49 (73) - Integra-B calls
.LB8FC
    JSR ConvertDateToAbsoluteDayNumber
    CLC
    RTS
			
;XY?0=&6B
;OSWORD &49 (73) - Integra-B calls
.LB901
    JSR ConvertAbsoluteDayNumberToDate
    CLC
    RTS

{
.ExitServiceCallIndirect
    JMP ExitServiceCall

; Error (BRK) occurred - Service call &06
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
    PHA
    LDA romselCopy:ORA #romselMemsel:STA romselCopy:STA romsel
    PLA
    RTS
}

; Copy our code stub into the OS printer buffer.
; SFTODO: This only has one caller at the moment and could be inlined.
.installOSPrintBufStub
{
BytesToCopy = osPrintBufSize
    ASSERT romCodeStubEnd - romCodeStub <= BytesToCopy

    LDX #BytesToCopy - 1
.Loop
    LDA romCodeStub,X:STA osPrintBuf,X
    DEX:BPL Loop
    ; Patch the stub so it contains our bank number.
    LDA romselCopy:AND #maxBank:STA osPrintBuf + (romCodeStubLoadBankImm + 1 - romCodeStub)
    RTS
}

; Code stub which is copied into the OS printer buffer at runtime by installOSPrintBufStub. The
; first 7 instructions are identical JSRs to the RAM copy of romCodeStubCallIBOS; these are
; (SFTODO: confirm this) installed as the targets of various non-extended vectors (SFTODO: by
; which subroutine?). The code at romCodeStubCallIBOS pages us in, calls the vectorEntry
; subroutine and then pages the previous ROM back in afterwards. vectorEntry is able to
; distinguish which of the 7 JSRs transferred control (and therefore which vector is being
; called) by examining the return address pushed onto the stack by that initial JSR.
;
; Doing all this avoids the use of the OS extended vector mechanism, which is relatively slow
; (particularly important for WRCHV, which gets called for every character output to the
; screen) and doesn't allow for vector chains.
;
; Note that while we have to save the originally paged in bank from romselCopy and restore it
; afterwards for obvious reasons (the caller is very likely directly or indirectly relying on
; this, e.g. a BASIC program will need the BASIC ROM to remain paged in after making an OS call
; which goes to IBOS!), this *also* has the effect of restoring the previous values of PRVEN
; and MEMSEL.
; SFTODO: I would like to get the whole ROM disassembled first before writing a permanent
; comment, but this is why e.g. rdchvHandler can do JSR setMemsel without explicitly reverting
; that change.
; SFTODO: Experience with Ozmoo suggests it's *probably* OK, but does IBOS always restore
; RAMSEL/RAMID to their original values if it changes them? Or at least the PRVSx bits?
.romCodeStub
ramCodeStub = osPrintBuf ; SFTODO: use ramCodeStub instead of osPrintBuf in some/all places?
{
    ASSERT P% - romCodeStub == ibosBYTEVIndex * 3:JSR ramCodeStubCallIBOS ; BYTEV
    ASSERT P% - romCodeStub == ibosWORDVIndex * 3:JSR ramCodeStubCallIBOS ; WORDV
    ASSERT P% - romCodeStub == ibosWRCHVIndex * 3:JSR ramCodeStubCallIBOS ; WRCHV
    ASSERT P% - romCodeStub == ibosRDCHVIndex * 3:JSR ramCodeStubCallIBOS ; RDCHV
    ASSERT P% - romCodeStub == ibosINSVIndex  * 3:JSR ramCodeStubCallIBOS ; INSV
    ASSERT P% - romCodeStub == ibosREMVIndex  * 3:JSR ramCodeStubCallIBOS ; REMV
    ASSERT P% - romCodeStub == ibosCNPVIndex  * 3:JSR ramCodeStubCallIBOS ; CNPV

.romCodeStubCallIBOS
ramCodeStubCallIBOS = ramCodeStub + (romCodeStubCallIBOS - romCodeStub)
    PHA
    PHP
    LDA romselCopy:PHA
.^romCodeStubLoadBankImm
    LDA #&00 ; patched at run time by installOSPrintBufStub
    STA romselCopy:STA romsel
    JSR vectorEntry
    PLA:STA romselCopy:STA romsel
    PLP
    PLA
    RTS
}
.romCodeStubEnd
ramCodeStubEnd = ramCodeStub + (romCodeStubEnd - romCodeStub)

; The next part of osPrintBuf is used to hold a table of 7 original OS (parent) vectors. This
; is really a single table, but because the 7 vectors of interest aren't contiguous in the OS
; vector table it's sometimes helpful to consider it as having two separate parts.
parentVectorTbl = ramCodeStubEnd
parentVectorTbl1 = parentVectorTbl
; The original OS (parent) values of BYTEV, WORDV, WRCHV and RDCHV are copied to
; parentVectorTbl1 in that order before installing our own handlers.
parentBYTEV = parentVectorTbl1
parentWORDV = parentVectorTbl1 + 2
parentVectorTbl2 = parentVectorTbl1 + 4 * 2 ; 4 vectors, 2 bytes each
; The original OS (parent) values of INSV, REMV and CNPV are copied to parentVectorTbl2 in that
; order before installing our own handlers.
parentVectorTbl2End = parentVectorTbl2 + 3 * 2 ; 3 vectors, 2 bytes each
ASSERT parentVectorTbl2End <= osPrintBuf + osPrintBufSize

; Restore A, X, Y and the flags from the stacked copies pushed during the vector entry process.
; The stack must have the same layout as described in the big comment in vectorEntry; note that
; the addresses in this subroutine are two bytes higher because we were called via JSR so we
; need to allow for our own return address on the stack.
.RestoreOrigVectorRegs
{
    TSX
    LDA L0108,X:PHA ; get original flags
    LDA L0109,X:PHA ; get original A
    LDA L0104,X:PHA ; get original X
    ; SQUASH: We could save a byte here by doing LDY L0103,X directly.
    LDA L0103,X:TAY ; get original Y
    PLA:TAX
    PLA
    PLP
    RTS
}

; This subroutine is the inverse of RestoreOrigVectorRegs; it takes the current values of A, X,
; Y and the flags and overwrites the stacked copies with them so they will be restored on
; returning from the vector handler.
.updateOrigVectorRegs
{
    ; At this point the stack is as described in the big comment in vectorEntry but with the
    ; return address for this subroutine also pushed onto the stack.
    PHP
    PHA
    TXA:PHA
    ; So at this point the stack is as described in the big comment in vectorEntry but with
    ; everything moved up five bytes (X=S-5, if S is the value of the stack pointer in that
    ; comment).
    TYA:TSX:STA L0106,X ; overwrite original stacked Y
    PLA:STA L0107,X ; overwrite original stacked X
    PLA:STA L010C,X ; overwrite original stacked A
    PLA:STA L010B,X ; overwrite original stacked flags
    RTS
}

; Table of vector handlers used by vectorEntry; addresses have -1 subtracted because we
; transfer control to these via an RTS instruction. The odd bytes between the addresses are
; there to match the spacing of the JSR instructions at osPrintBuf; the actual values are
; irrelevant and will never be used.
; SFTODO: Are they really unused? Maybe there's some code hiding somewhere, but nothing
; references this label except the code at vectorEntry. It just seems a bit odd these bytes
; aren't 0.
.vectorHandlerTbl
ibosBYTEVIndex = (P% - vectorHandlerTbl) DIV 3
    EQUW bytevHandler-1
    EQUB &0A
ibosWORDVIndex = (P% - vectorHandlerTbl) DIV 3
    EQUW wordvHandler-1
    EQUB &0C
ibosWRCHVIndex = (P% - vectorHandlerTbl) DIV 3
    EQUW WrchvHandler-1
    EQUB &0E
ibosRDCHVIndex = (P% - vectorHandlerTbl) DIV 3
    EQUW rdchvHandler-1
    EQUB &10
ibosINSVIndex = (P% - vectorHandlerTbl) DIV 3
    EQUW InsvHandler-1
    EQUB &2A
ibosREMVIndex = (P% - vectorHandlerTbl) DIV 3
    EQUW RemvHandler-1
    EQUB &2C
ibosCNPVIndex = (P% - vectorHandlerTbl) DIV 3
    EQUW CnpvHandler-1
    EQUB &2E

; Control arrives here via ramCodeStub when one of the vectors we've claimed is
; called.
.vectorEntry
{
    TXA:PHA
    TYA:PHA
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
    ;
    ; The low byte of the return address at &108,S will be the address of the JSR
    ; ramCodeStubCallIBOS plus 2. We mask off the low bits (which are sufficient to distinguish
    ; the 7 different callers) and use them to transfer control to the handler for the relevant
    ; vector.
    TSX:LDA L0108,X:AND #&3F:TAX
    LDA vectorHandlerTbl-1,X:PHA
    LDA vectorHandlerTbl-2,X:PHA
    RTS
}

; Clean up and return from a vector handler; we have dealt with the call and we're not going to
; call the parent handler. At this point the stack should be exactly as described in the big
; comment in vectorEntry; note that this code is reached via JMP so there's no extra return
; address on the stack as there is in RestoreOrigVectorRegs.
.returnFromVectorHandler
{
    ; SQUASH: This is really just shuffling the stack down to remove the return address from
    ; "JSR ramCodeStubCallIBOS"; can we rewrite it more compactly using a loop?
    TSX
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
    ;
    ; We now restore Y and X and RTS from "JSR vectorEntry" in ramCodeStub, which will restore
    ; the previously paged in ROM, the flags and then A, so the vector's caller will see the
    ; Z/N flags reflecting A, but otherwise preserved.
    PLA:TAY
    PLA:TAX
    RTS
}

; Restore the registers and pass the call onto the parent vector handler for vector A (using
; the ibos*Index numbering). At this point the stack should be exactly as described in the big
; comment in vectorEntry; note that this code is reached via JMP so there's no extra return
; address on the stack as there is in RestoreOrigVectorRegs.
.forwardToParentVectorTblEntry
    TSX
    ASL A:TAY
    ; We need to subtract 1 from the destination address because we're going to transfer
    ; control via RTS, which will add 1. We overwrite the return address from "JSR
    ; ramCodeStubCallIBOS" on the stack.
    SEC
    LDA parentVectorTbl,Y:SBC #1:STA L0108,X
    LDA parentVectorTbl+1,Y:SBC #0:STA L0109,X
    PLA:TAY
    PLA:TAX
    RTS

; Aries/Watford shadow RAM access (http://beebwiki.mdfs.net/OSBYTE_%266F)
.osbyte6FHandler
    JSR osbyte6FInternal
    JMP returnFromBYTEV

; Read key with time limit/read machine type (http://beebwiki.mdfs.net/OSBYTE_%2681)
.osbyte81Handler
{
    CPX #0:BNE osbyte87Handler
    CPY #&FF:BNE osbyte87Handler
    LDX #prvOsMode - prv83:JSR ReadPrivateRam8300X
    BEQ OsMode01
    CMP #1:BEQ OsMode01
    ; Return with X containing the appropriate value from OsModeLookupTable.
    TAX:LDA OsModeLookupTable,X:TAX
    LDY #0
    BEQ returnFromBYTEV ; always branch
.OsMode01
    ; Restore the registers and let the OS handle this call.
    LDX #0:LDA #&81:JMP returnViaParentBYTEV

; SQUASH: If we used "LDA OsModeLookupTable - 2,X" we could eliminate the first two entries in
; this table, and I don't think there's any need to keep the OSMODE 6/7 entries either.
.OsModeLookupTable
    EQUB &01 ; OSMODE 0 - not used
    EQUB &01 ; OSMODE 1 - not Used
    EQUB &FB ; OSMODE 2
    EQUB &FD ; OSMODE 3
    EQUB &FB ; OSMODE 4
    EQUB &F5 ; OSMODE 5
    EQUB &01 ; OSMODE 6 - no such mode
    EQUB &01 ; OSMODE 7 - no such mode
}

.jmpParentBYTEV
    JMP (parentBYTEV)

; BYTEV handler. This is used to override the OS implementation of OSBYTE calls; only
; *unrecognised* OSBYTE calls will be passed through via service07.
.bytevHandler
    JSR RestoreOrigVectorRegs
    ; SQUASH: Is there any chance of saving a few bytes by converting this to a jump table?
    CMP #&6F:BEQ osbyte6FHandler
    CMP #&98:BEQ osbyte98Handler
    CMP #&87:BEQ osbyte87Handler
    CMP #&84:BEQ osbyte84Handler
    CMP #&85:BEQ osbyte85Handler
    CMP #&8E:BEQ osbyte8EHandler
    CMP #&00:BEQ osbyte00Handler
    CMP #&81:BEQ osbyte81Handler
    LDA #ibosBYTEVIndex:JMP forwardToParentVectorTblEntry ; SQUASH: BNE always?

; Read character at text cursor and screen mode (http://beebwiki.mdfs.net/OSBYTE_%2687)
.osbyte87Handler
    JSR setMemsel
    JMP returnViaParentBYTEV

; Examine buffer status (http://beebwiki.mdfs.net/OSBYTE_%2698)
; SFTODO: What's going on here? Why do we need to override the OS implementation of this at
; all? See the ENHANCE: comment above PrintBufferNotEmpty, but I'm not sure that's relevant -
; note that we are accessing the OS 1.20 buffer via OS pointer &FA, which will *only* work if
; the buffer is the standard OS one not something else (such as our own printer buffer).
.osbyte98Handler
    JSR jmpParentBYTEV:BCS returnFromBYTEV ; branch if buffer empty
    ; SFTODO: Why is this taking more care than usual (PRVEN or ReadPrivateRam8300X) to
    ; preserve RAMSEL/ROMSEL? Something to do with printer buffer support? But even so, does
    ; this suggest there's a risk of undoing user changes to RAMSEL/ROMSEL in other cases?
    XASSERT_USE_PRV1
    LDA ramselCopy:PHA:ORA #ramselPrvs1:STA ramselCopy:STA ramsel
    LDA romselCopy:PHA:ORA #romselPrvEn:STA romselCopy:STA romsel
    LDA prvOsMode:CMP #2
    PLA:STA romselCopy:STA romsel
    PLA:STA ramselCopy:STA ramsel
    BCC returnFromBYTEV ; branch if we're in OSMODE 0 or 1
    ; SFTODO: Set C/A/Y up exactly as the OS would/should have left them anyway?!
    CLC
    LDA (L00FA),Y:TAY ; get character from OS buffer
    LDA #&98
.returnFromBYTEV
    JSR updateOrigVectorRegs
    JMP returnFromVectorHandler

{
; Read top of user memory (http://beebwiki.mdfs.net/OSBYTE_%2684)
.^osbyte84Handler
    PHA
    LDA vduStatus:AND #vduStatusShadow:BNE ShadowMode
    PLA
    JMP returnViaParentBYTEV

; Read base of display RAM for a given mode (http://beebwiki.mdfs.net/OSBYTE_%2685)
.^osbyte85Handler
    PHA
    TXA:BMI ShadowMode
    LDA osShadowRamFlag:BEQ ShadowMode
    PLA
    JMP returnViaParentBYTEV

.ShadowMode
    PLA
    LDX #lo(shadowHimem):LDY #hi(shadowHimem)
    JMP returnFromBYTEV
}

; Enter language ROM (http://beebwiki.mdfs.net/OSBYTE_%268E)
.osbyte8EHandler
    ; We emulate the Master's behaviour by issuing this service call to notify sideways ROMs
    ; before entering the language.
    LDA #osbyteIssueServiceRequest:LDX #serviceAboutToEnterLanguage:LDY #0:JSR OSBYTE
    JSR RestoreOrigVectorRegs
    JMP returnViaParentBYTEV

; Identify host/operating system (http://beebwiki.mdfs.net/OSBYTE_%2600)
.osbyte00Handler
{
    TXA:PHA
    LDX #prvOsMode - prv83:JSR ReadPrivateRam8300X
    BEQ OsMode0
    CMP #4:BNE NotOsMode4
    LDA #2 ; return with X=2 in OSMODE 4, otherwise return with X=OSMODE
.NotOsMode4
    TAX
    PLA:BEQ OriginalX0
    ; This is OSBYTE &00 with X<>0, so return with our new X.
    LDA #&00:JMP returnFromBYTEV ; SQUASH: BEQ always?

.OsMode0
    ; In OSMODE 0 we always let our parent handle this call.
    PLA:TAX
    LDA #&00
.^returnViaParentBYTEV
    JSR jmpParentBYTEV
    JMP returnFromBYTEV

    ; SQUASH: I think we could do this loop backwards to save two bytes on CPX #
.OriginalX0
    ; This is OSBYTE &00 with X=0, meaning we should generate an error showing the OS version.
    LDX #0
.Loop
    LDA osError,X:STA L0100,X
    INX:CPX #osErrorEnd - osError:BNE Loop
    LDX #prvOsMode - prv83:JSR ReadPrivateRam8300X:ORA #'0':STA L0100 + (osErrorOsMode - osError)
    JMP L0100
.osError
    EQUB &00,&F7
    EQUS "OS 1.20 / OSMODE "
.osErrorOsMode
    EQUS "0", &00
.osErrorEnd
}

{
.jmpParentWORDV
    JMP (parentWORDV)

.^wordvHandler
    JSR RestoreOrigVectorRegs
    CMP #oswordReadPixel:BNE NotReadPixel
    ; We need to make sure the video RAM is paged in for the pixel read to work.
    ; SFTODO: Prob true, but not followed code through precisely yet.
    JSR setMemsel
    JSR jmpParentWORDV
    JSR updateOrigVectorRegs
    JMP returnFromVectorHandler
.NotReadPixel
    LDA #ibosWORDVIndex:JMP forwardToParentVectorTblEntry
}

{
.jmpParentRDCHV
    JMP (parentVectorTbl + ibosRDCHVIndex * 2)

; It seems a bit counter-intuitive that IBOS needs a RDCHV handler at all, but I believe this
; is needed so cursor editing can work - the OS will try to read from screen memory to work out
; what character is currently on the screen when copying text. OS 1.20 doesn't call OSBYTE &87
; to read the character, it just calls its own internal OSBYTE &87 implementation directly via
; JSR.
.^rdchvHandler
    JSR setMemsel
    JSR RestoreOrigVectorRegs
    JSR jmpParentRDCHV
    JSR updateOrigVectorRegs
    JMP returnFromVectorHandler
}

{
.jmpParentWRCHV
    JMP (parentVectorTbl + ibosWRCHVIndex * 2)

; We're processing OSWRCH with A=vduSetMode. That is only actually a set mode call if we're not
; part-way through a longer VDU sequence (e.g. VDU 23,128,22,...), so check that and set
; ModeChangeState to ModeChangeStateSeenVduSetMode if we *are* going to change mode.
.OswrchVduSetMode
    PHA
    LDA negativeVduQueueSize:BNE InLongerVduSequence
    ; SQUASH: We know ModeChangeState is 0 here, so we could just do ASSERT ModeChangeStateNone
    ; + 1 == ModeChangeStateSeenVduSetMode;INC ModeChangeState.
    LDA #ModeChangeStateSeenVduSetMode:STA ModeChangeState
.InLongerVduSequence
    PLA:JMP ProcessWrchv

; The following scope is the WRCHV handler; the entry point is at WrchvHandler half way down.
; We're processing the second byte of a vduSetMode command, i.e. we will change mode when we
; forward this byte to the parent WRCHV.
.SelectNewMode
    PLA:PHA ; peek original OSWRCH A=new mode
    CMP #shadowModeOffset:BCS EnteringShadowMode
    LDA osShadowRamFlag:BEQ EnteringShadowMode
    ; We're entering a non-shadow mode.
    PLA:PHA ; peek original OSWRCH A=new mode SQUASH: redundant, MaybeSwapShadow2 does LDA
    JSR MaybeSwapShadow2
    LDA ramselCopy:AND_NOT ramselShen:STA ramselCopy:STA ramsel
    PLA:PHA ; peek original OSWRCH A=new mode
    AND_NOT shadowModeOffset ; SQUASH: redundant as we didn't take "BCS EnteringShadowMode" branch above
    LDX #prvLastScreenMode - prv83:JSR WritePrivateRam8300X
    LDA #ModeChangeStateEnteringNonShadowMode:STA ModeChangeState
    PLA:JMP ProcessWrchv

.EnteringShadowMode
    LDA ramselCopy:ORA #ramselShen:STA ramselCopy:STA ramsel
    JSR MaybeSwapShadow1
    PLA:PHA ; peek original OSWRCH A=new mode
    ORA #shadowModeOffset:LDX #prvLastScreenMode - prv83:JSR WritePrivateRam8300X
    ; SQUASH: Share STA ModeChangeState:PLA:JMP ProcessWrchv with code above?
    LDA #ModeChangeStateEnteringShadowMode:STA ModeChangeState
    PLA:JMP ProcessWrchv

.CheckOtherModeChangeStates
    CMP #ModeChangeStateEnteringNonShadowMode
    BNE WrchvHandlerDone
    BEQ AdjustCrtcHorz

.^WrchvHandler
    JSR RestoreOrigVectorRegs
    PHA
    LDA ModeChangeState:BNE SelectNewMode
    PLA
    CMP #vduSetMode:BEQ OswrchVduSetMode
.ProcessWrchv ; SFTODO: not a great name...
    JSR setMemsel
    JSR jmpParentWRCHV
    PHA
    LDA ModeChangeState:CMP #ModeChangeStateEnteringShadowMode:BNE CheckOtherModeChangeStates
    LDA vduStatus:ORA #vduStatusShadow:STA vduStatus
.AdjustCrtcHorz
    ; DELETE: There seems to be an undocumented feature of IBOS which will perform a horizontal
    ; screen shift (analogous to the vertical shift controlled by *TV/*CONFIGURE TV) based on
    ; userRegHorzTV. This is not exposed in *CONFIGURE/*STATUS, but it does seem to work if you
    ; use *FX162,54 to write directly to the RTC register. In a modified IBOS this should
    ; probably either be removed to save space or exposed via *CONFIGURE/*STATUS.
    LDX #userRegHorzTV:JSR ReadUserReg
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
.WrchvHandlerDone
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
.^MaybeSwapShadow1
    LDA vduStatus:AND #vduStatusShadow:BEQ SwapShadowIfShxEnabled
    RTS

; SFTODO: This has only one caller
.^MaybeSwapShadow2
    LDA vduStatus:AND #vduStatusShadow
    ; SQUASH: Rewriting the next two lines as "BEQ some-rts-somewhere:FALLTHROUGH_TO
    ; SwapShadowIfShxEnabled" would save a byte.
    BNE SwapShadowIfShxEnabled
    RTS

; If SHX is enabled, swap the contents of main and shadow RAM between &3000-&7FFF.
; ENHANCE: If we could speed this up (e.g. by using a buffer in private RAM to swap a page at a
; time, instead of having to toggle MEMSEL twice per byte of screen memory), we could encourage
; having SHX enabled (e.g. make it the default). Acorn shadow RAM on the B+ and M128 always
; behaves as if SHX is enabled, so having it on reduces scope for surprise program corruption.
; (It's not as large as I'd like, but &80xx is probably available for use here.)
.SwapShadowIfShxEnabled
    LDX #prvShx - prv83:JSR ReadPrivateRam8300X:BEQ Rts ; nothing to do if SHX off
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
    LDX #prvOsMode - prv83:JSR ReadPrivateRam8300X:BEQ OsMode0
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
    LDX #prvLastScreenMode - prv83:JSR ReadPrivateRam8300X:BPL DisableShadow
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
    PRVEN
    LDA prvLastScreenMode:AND_NOT shadowModeOffset:STA prvLastScreenMode
    JMP PrvDis ; SFTODO: Should have PRVDIS-like macro for this case
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
    ; SQUASH: I think the next few lines up to and including "PRVDIS" could be replaced by
    ; "JSR SFTODOCOMMON1".
    PRVEN
    LDA prvLastScreenMode:AND_NOT shadowModeOffset:STA prvLastScreenMode
    PRVDIS
    JSR MaybeSwapShadow2
    JMP DisableShadow
}

; Page in PRVS8 and PRVS1, returning the previous value of RAMSEL in A.
; SFTODO: From vague memories of other bits of the code, sometimes we do this
; sort of paging in a bit more ad-hocly, without updating &F4/&37F. So we may
; want to note in the comment that this does the paging in
; properly/formally/some other term.
.pageInPrvs81
    LDA romselCopy:ORA #romselPrvEn:STA romselCopy:STA romsel
    LDA ramselCopy:PHA:ORA #ramselPrvs81:STA ramselCopy:STA ramsel:PLA
    RTS

.InsvHandler
{
    TSX:LDA L0102,X ; get original X=buffer number
    CMP #bufNumPrinter:BEQ IsPrinterBuffer
    LDA #ibosINSVIndex:JMP forwardToParentVectorTblEntry

.IsPrinterBuffer
    PRVS81EN
    PHA
    TSX
    JSR CheckPrintBufferFull:BCC PrintBufferNotFull
    ; Return to caller with carry set to indicate insertion failed.
    LDA L0107,X:ORA #flagC:STA L0107,X ; modify stacked flags so C is set
    JMP RestoreRamselClearPrvenReturnFromVectorHandler

.PrintBufferNotFull
    LDA L0108,X ; get original A=character to insert
    JSR StaPrintBufferWritePtr
    JSR AdvancePrintBufferWritePtr
    JSR DecrementPrintBufferFree
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
    PRVS81EN
    PHA
    TSX
    JSR CheckPrintBufferEmpty:BCC PrintBufferNotEmpty
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
    JSR LdaPrintBufferReadPtr
    TSX
    PHA ; note this doesn't affect X so our L01xx,X references stay the same
    LDA L0107,X:AND #flagV:BNE ExamineBuffer ; test V in stacked flags from caller
    ; V was cleared by the caller, so we're removing a character from the buffer.
    PLA:STA L0108,X ; overwrite stacked A with character read from our buffer
    JSR AdvancePrintBufferReadPtr
    JSR IncrementPrintBufferFree
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
    PRVEN
    TSX:LDA L0107,X:AND #flagV:BEQ Count ; test V in stacked flags from caller
    ; We're purging the buffer.
    LDX #prvPrintBufferPurgeOption - prv83:JSR ReadPrivateRam8300X:BEQ PurgeOff
    JSR PurgePrintBuffer
.PurgeOff
    JMP RestoreRamselClearPrvenReturnFromVectorHandler

.Count
    LDA L0107,X:AND #flagC:BNE CountSpaceLeft ; test C in stacked flags from caller
    ; We're counting the entries in the buffer; return them as 16-bit value YX.
    JSR GetPrintBufferUsed
    TXA:TSX:STA L0103,X ; overwrite stacked X, so we return A to caller in X
    TYA:STA L0102,X ; overwrite stacked Y, so we return A to caller in Y
    JMP RestoreRamselClearPrvenReturnFromVectorHandler

.CountSpaceLeft
    ; We're counting the space left in the buffer; return that as 16-bit value YX.
    JSR GetPrintBufferFree
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
    LDX lastBreakType:BEQ SoftReset
    ; On hard break or power-on reset, set up the printer buffer so it uses private RAM from
    ; prvPrvPrintBufferStart onwards.
    PRVEN
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
.SoftReset
    JSR PurgePrintBuffer
    PRVDIS
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
; Advance prvPrintBufferReadPtr by one, wrapping round at the end of each bank and wrapping
; round at the end of the bank list.
.^AdvancePrintBufferReadPtr
    LDX #prvPrintBufferReadPtrIndex
    ASSERT prvPrintBufferReadPtrIndex != 0:BNE Common ; always branch

; Advance prvPrintBufferWritePtr by one, wrapping round at the end of each bank and wrapping
; round at the end of the bank list.
.^AdvancePrintBufferWritePtr
    LDX #prvPrintBufferWritePtrIndex
.Common
    XASSERT_USE_PRV1
    INC prvPrintBufferPtrBase    ,X:BNE Rts
    INC prvPrintBufferPtrBase + 1,X
    LDA prvPrintBufferPtrBase + 1,X:CMP prvPrintBufferBankEnd:BCC Rts
    LDY prvPrintBufferPtrBase + 2,X:INY:CPY #MaxPrintBufferSwrBanks:BCC DontWrap1
    LDY #0
.DontWrap1
    LDA prvPrintBufferBankList,Y:BPL DontWrap2
    ; Top bit of this bank number is set, so it's going to be $FF indicating an invalid bank;
    ; wrap round to the first bank.
    LDY #0
.DontWrap2
    TYA:STA prvPrintBufferPtrBase + 2,X
    ; SQUASH: Next line is redundant, INC prvPrintBufferPtrBase,X left this 0 above.
    LDA #0:STA prvPrintBufferPtrBase,X
    LDA prvPrintBufferBankStart:STA prvPrintBufferPtrBase + 1,X
.Rts
    RTS
}

{
; Return with carry set if and only if the printer buffer is full.
; SQUASH: This has only one caller
.^CheckPrintBufferFull
    XASSERT_USE_PRV1
    LDA prvPrintBufferFreeLow:ORA prvPrintBufferFreeMid:ORA prvPrintBufferFreeHigh:BEQ SecRts
    CLC
    RTS
.SecRts ; SQUASH: Re-use the SEC:RTS just below.
    SEC
    RTS

; Return with carry set if and only if the printer buffer is empty.
; SQUASH: This has only one caller
.^CheckPrintBufferEmpty
    XASSERT_USE_PRV1
    LDA prvPrintBufferFreeLow:CMP prvPrintBufferSizeLow:BNE ClcRts
    LDA prvPrintBufferFreeMid:CMP prvPrintBufferSizeMid:BNE ClcRts
    ; ENHANCE: Next line is a duplicate of previous one, it should be checking High not Mid.
    LDA prvPrintBufferFreeMid:CMP prvPrintBufferSizeMid:BNE ClcRts
    SEC
    RTS
.ClcRts ; SQUASH: Re-use the CLC:RTS just above.
    CLC
    RTS
}

; SQUASH: This currently only has one caller, so could be inlined. Although maybe there's some
; critical alignment stuff going on, which means certain code has to live in the &Bxxx region
; so it can be accessed while private RAM is paged in. But we could potentially move the caller
; (or just all INSV/CNPV/REMV code??) into &Bxxx, although it may not be worth the hassle.
.GetPrintBufferFree
{
    XASSERT_USE_PRV1
    LDX prvPrintBufferFreeHigh:BNE AtLeast64KFree
    LDX prvPrintBufferFreeLow:LDY prvPrintBufferFreeMid
    RTS
.AtLeast64KFree
    ; Tell the caller there's 64K-1 byte free, which is the maximum return value.
    LDX #&FF:LDY #&FF
    RTS
}

; SQUASH: This currently only has one caller.
.GetPrintBufferUsed
    XASSERT_USE_PRV1
; SFTODO: Won't this incorrectly return 0 if a 64K buffer is entirely full? Do
; we prevent this happening somehow? This could be tested fairly easily by
; simply having no printer connected/turned on, setting a 64K buffer, writing
; 64K to it and then calling CNPV to query the amount of data in the buffer. It's
; possible the nature of the (presumably) circular print buffer means it can
; never actually contain more than 64K-1 bytes even if it's 64K, but that's
; just speculation.
    SEC
    LDA prvPrintBufferSizeLow:SBC prvPrintBufferFreeLow:TAX
    LDA prvPrintBufferSizeMid:SBC prvPrintBufferFreeMid:TAY
    RTS

; SQUASH: This has only a single caller
.IncrementPrintBufferFree
{
    XASSERT_USE_PRV1
    INC prvPrintBufferFreeLow
    BNE NoCarry ; ENHANCE: Would be clearer to just BNE Rts
    INC prvPrintBufferFreeMid
.NoCarry
    BNE Rts
    INC prvPrintBufferFreeHigh
.Rts
    RTS
}

; SQUASH: This has only a single caller
; SQUASH: Use decrement-by-one technique from http://www.obelisk.me.uk/6502/algorithms.html
.DecrementPrintBufferFree
    XASSERT_USE_PRV1
    SEC
    LDA prvPrintBufferFreeLow:SBC #1:STA prvPrintBufferFreeLow
    LDA prvPrintBufferFreeMid:SBC #0:STA prvPrintBufferFreeMid
    DECCC prvPrintBufferFreeHigh
    RTS

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

{
; Temporarily page in ROM bank prvPrintBufferBankList[prvPrintBufferReadBankIndex] and do LDA (prvPrintBufferReadPtr)
.^LdaPrintBufferReadPtr
    PHA
    LDX #prvPrintBufferReadPtrIndex
    LDA #opcodeLdaAbs
    BNE Common ; always branch

; Temporarily page in ROM bank prvPrintBufferBankList[prvPrintBufferWriteBankIndex] and do STA (prvPrintBufferWritePtr)
.^StaPrintBufferWritePtr
    PHA
    LDX #prvPrintBufferWritePtrIndex
    LDA #opcodeStaAbs
.Common
    XASSERT_USE_PRV1
    STA ramRomAccessSubroutineVariableInsn
    LDA prvPrintBufferPtrBase    ,X:STA ramRomAccessSubroutineVariableInsn + 1
    LDA prvPrintBufferPtrBase + 1,X:STA ramRomAccessSubroutineVariableInsn + 2
    LDY prvPrintBufferPtrBase + 2,X:LDA prvPrintBufferBankList,Y:TAY
    PLA
    JMP ramRomAccessSubroutine
}

.PurgePrintBuffer
    XASSERT_USE_PRV1
    LDA #0:STA prvPrintBufferWritePtr:STA prvPrintBufferReadPtr
    LDA prvPrintBufferBankStart:STA prvPrintBufferWritePtr + 1:STA prvPrintBufferReadPtr + 1
    LDA prvPrintBufferFirstBankIndex:STA prvPrintBufferWriteBankIndex:STA prvPrintBufferReadBankIndex
    LDA prvPrintBufferSizeLow:STA prvPrintBufferFreeLow
    LDA prvPrintBufferSizeMid:STA prvPrintBufferFreeMid
    LDA prvPrintBufferSizeHigh:STA prvPrintBufferFreeHigh
    RTS

; If prvPrvPrintBufferStart isn't in the range &90-&AC, set it to &AC. We return with prvPrvPrintBufferStart in A.
.SanitisePrvPrintBufferStart
{
MaxPrintBufferStart = prv8End - 1024 ; print buffer must be at least 1K

    ; SQUASH: We could change "BCC Rts" below to use the RTS above and make the JSR:RTS a JMP.
    LDX #prvPrvPrintBufferStart - prv83:JSR ReadPrivateRam8300X
    CMP #hi(prv8Start):BCC UseAC
    CMP #hi(MaxPrintBufferStart):BCC Rts
.UseAC
    LDA #hi(MaxPrintBufferStart):JSR WritePrivateRam8300X
.Rts
    RTS
}

PRINT end - P%, "bytes free"
SAVE "IBOS-01.rom", start, end

; SFTODO: Would it be possible to save space by factoring out "LDX #prvOsMode:JSR
; ReadPrivateRam8300X" into a subroutine?

; SQUASH: We may be able to save some space by paging in PRV1 and accessing it
; directly instead of using {Read,Write}PrivateRam8300X in some places.

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

; SFTODO: Minor inconsistency between "PrintBuffer" and "PrinterBuffer" in various labels

; SFTODO: *If* GXR has some incompatibilities with shadow mode on Integra-B, we could produce a
; patched GXR for it - I already have a half-decent disassembly at
; https://github.com/ZornsLemma/GXR.

; It would be nice if "*CO." could be used as an abbreviation for *CONFIGURE, as on the Master,
; but OS 1.20 interprets this as an abbreviate for "*CODE" and IBOS never gets a chance to see
; it. Short of installing a USERV handler, there isn't much we can do about this.

;; Local Variables:
;; fill-column: 95
;; End:
