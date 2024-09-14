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

; INCLUDE_APPEND will normally be TRUE in a release build, but setting it to FALSE removes
; *APPEND to free up space for experimental changes.
INCLUDE_APPEND = TRUE ; (IBOS_VERSION < 127)

IF IBOS_VERSION != 120
    IBOS120_VARIANT = 0
ENDIF

; This code uses macro names which start with 6502 mnemonics, which beebasm only allows if the
; -w option is used. Deliberately generate an error ASAP if this is the case with a comment
; on the problematic line to tell the user how to fix the problem.
MACRO INCTEST
ENDMACRO
INCTEST ; if this fails to assemble, please give beebasm the "-w" option

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
;49 - prvSetPrinterTypePending

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
;The hex values shown after the register numbers are the defaults, where these are simple
;enough to include. Defaults may vary with IBOS version and the full details can be seen in the
;code at UserRegDefaultTable.
;Register &00
;Register &01
;Register &02
;Register &03
;Register &04
;Register &05 -               <v1.26: 0-3: FILE, 4-7: LANG / >=v1.26: 0-3: non-tube-LANG, 4-7: tube-LANG
;Register &06 - &FF:	*INSERT status for ROMS &0F to &08. Default: &FF (All 8 ROMS enabled)
;Register &07 - &FF:	*INSERT status for ROMS &07 to &00. Default: &FF (All 8 ROMS enabled)
;Register &08
;Register &09
;Register &0A - &17/&E7:	0-2: MODE / 3: SHADOW / 4: TV Interlace / 5-7: TV screen shift
;Register &0B - &23:	0-2: FDRIVE / 3-5: CAPS
;Register &0C - &19:	0-7: Keyboard Delay
;Register &0D - &05:	0-7: Keyboard Repeat
;Register &0E - &0A:	0-7: Printer Ignore
;Register &0F - &2D:	0: Tube / 2-4: BAUD / 5-7: Printer
;Register &10 - &A0:	0: File system disc/net flag / 4: Boot / 5-7: Data
;Register &11 - &FF:          <v1.26: unused / >=v1.26: 0-3: FILE, 4-7: spare
;Register &31 - &00:          >=v1.27: PALPROM Config: 0-1: Spare / 2: pp2a / 3: pp2b / 4..5: pp4a / 6..7: pp8a


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
IF IBOS_VERSION < 126
userRegLangFile = &05 ; b0-3: FILE, b4-7: LANG
ELSE
userRegLang = &05 ; b0-3: LANG for no tube present, b4-7: LANG for tube present
userRegFile = &11; b0-3: FILE, b4-7: spare
ENDIF
userRegBankInsertStatus = &06 ; 2 bytes, 1 bit per bank, bit number == bank number
userRegModeShadowTV = &0A ; 0-2: MODE / 3: SHADOW / 4: TV interlace / 5-7: TV screen shift
userRegFdriveCaps = &0B ; 0-2: FDRIVE / 3-5: CAPS
userRegKeyboardDelay = &0C ; 0-7: Keyboard delay
userRegKeyboardRepeat = &0D ; 0-7: Keyboard repeat
userRegPrinterIgnore = &0E ; 0-7: Printer ignore
userRegTubeBaudPrinter = &0F  ; 0: Tube / 2-4: Baud / 5-7: Printer
userRegDiscNetBootData = &10 ; 0: File system disc/net flag / 4: Boot / 5-7: Data
IF IBOS_VERSION >= 127
;userDefaultRegBankWriteProtectStatus = &2F ; 2 bytes
userRegPALPROMConfig = &31 ;   0: Unused
		       ;   1: Bank  8 Enable / Disable
		       ;   2: Bank  9 Enable / Disable
		       ;   3: Bank 10 Enable / Disable
		       ; 4-5: Bank 10 Switching zone model select
		       ;   6: Bank 11 Enable / Disable
		       ;   7: Bank 11 Switching zone model select
ENDIF
userRegOsModeShx = &32 ; 0-2: OSMODE / 3: SHX / 4: automatic daylight saving time adjust SFTODO: Should rename this now we've discovered b4
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
; userRegRamPresenceFlags has a bit set for every 32K of RAM. Bit n represents sideways ROM
; banks 2n and 2n+1; however, bits 0 and 1 are effectively repurposed to represent the 64K of
; non-sideways RAM (the 32K on the model B, plus the 32K of shadow/private RAM on the
; Integra-B). Banks 0-3 are the sockets on the motherboard and are assumed to never contain
; RAM, so there's no conflict here; see the code for *ROMS, which treats banks 0-3 differently.
; ENHANCE: Could we auto-detect this on startup instead of requiring the user to configure it?
; Maybe stop treating banks 0-3 as a special case and just add 64K (for the main and
; shadow/private RAM) to the sideways RAM count when displaying the banner? Ken already has
; some code to change the behaviour in this area.
;
; KL 3/8/24: userRegRamPresenceFlags0_7 & userRegRamPresenceFlags8_F used in IBOS1.27 and above.
IF IBOS_VERSION < 127
userRegRamPresenceFlags = &7F
ELSE
userRegTmp = &7C ; 2 bytes for temporary use
userRegRamPresenceFlags0_7 = &7E
userRegRamPresenceFlags8_F = &7F
ENDIF

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

IF IBOS_VERSION >= 127
transientBin = &AE	;2 bytes added by KL for IBOS1.27
transientBCD = &AC	;2 bytes added by KL for IBOS1.27
ENDIF

FilingSystemWorkspace = &B0; IBOS repurposes this, which feels a bit risky but presumably works in practice
ConvertIntegerResult = FilingSystemWorkspace ; 4 bytes

vduStatus = &D0
vduStatusShadow = &10
osEscapeFlag = &FF
romActiveLastBrk = &024A
negativeVduQueueSize = &026A
tubePresenceFlag = &027A ; SFTODO: allmem says 0=inactive, is there actually a specific bit or value for active? what does this code rely on?
osShadowRamFlag = &027F ; *SHADOW option, 1=force shadow mode, 0=don't force shadow mode
breakInterceptJmp = &0287 ; memory location corresponding to *FX247
currentLanguageRom = &028C ; SFTODO: not sure yet if we're using this for what the OS does or repurposing it
osfileBlock = &02EE ; OS OSFILE block for *LOAD, *SAVE, etc
currentMode = &0355
; &03A4 is the "GXR flag byte" according to allmem.txt; IBOS seems to repurpose it to track
; full resets (done with the "@" key held down) across multiple service calls during a reset.
; &FF means a full reset is in progress, 0 means normal.
FullResetFlag = &03A4

RomTypeTable = &02A1
romPrivateWorkspaceTable = &0DF0

RomTypeSrData = 2 ; ROM type byte used for banks allocated to pseudo-addressing via *SRDATA

CapitaliseMask = &DF
LowerCaseMask = &20

osWrscPtr = &D6
osBrkStackPointer = &F0
osCmdPtr = &F2
osErrorPtr = &FD
osRdRmPtr = &F6
osIrqA = &FC

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
IF IBOS_VERSION < 126
; SQUASH: I am not sure CmdTblPtrOffset is actually useful - every "table" holds a different
; data structure in the thing pointed to by CmdTblPtrOffset so there's no generic code which
; uses this pointer - we can just hard-code the relevant address where we need it and not lose
; any real generality.
CmdTblPtrOffset = 10
ENDIF

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
RomAccessSubroutine = &0380
variableMainRamSubroutine = &03A7 ; SFTODO: POOR NAME
; SFTODO: I don't know if RomAccessSubroutine does actually need to avoid overlapping
; variableMainRamSubroutine; should check.
RomAccessSubroutineMaxSize = variableMainRamSubroutine - RomAccessSubroutine
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

; The following constants define stack addresses for values which are on the stack inside
; VectorEntry; see the comment there for more details. These are typically used in code of the
; form "TSX:LDA VectorEntryStackedFoo+n,X", where n is a small constant offset to allow for
; additional values pushed onto the stack between VectorEntry and the point at which the LDA is
; executing.
; SFTODO: It might be worth doing this for other stack accesses too, e.g. the service call
; handler stacked A/X/Y/flags.
VectorEntryStackedY     = &101
VectorEntryStackedX     = &102
VectorEntryStackedFlags = &106
VectorEntryStackedA     = &107

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

OSWRSC = &FFB3
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

IF IBOS_VERSION >= 127
cpldRAMROMSelectionFlags0_3_V2Status = SHEILA + &38 ; read
cpldRAMROMSelectionFlags8_F = SHEILA + &39 ; read
cpldExtendedFunctionFlags = SHEILA + &39 ; write
cpldRamWriteProtectFlags0_7 = SHEILA + &3A ; read / write
cpldRamWriteProtectFlags8_F = SHEILA + &3B ; read / write
cpldPALPROMSelectionFlags0_7 = SHEILA + &3F ; read
ENDIF

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
IF IBOS_VERSION < 127
; prvPrintBufferBankCount seems to be the number of banks of sideways RAM allocated to the
; printer buffer; it's 0 if there's no buffer or the buffer is in private RAM.
prvPrintBufferBankCount = prv82 + &0F
ENDIF
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
; SFTODO: It might be a good idea to move all the "pseudo-registers" up one and start with B, then we don't have a clash with the CPU's A register and thinking/talking about things gets a little easier. (C still clashes with carry, but that's not a massive problem, ditto D. We could start at E just to be completely unambiguous though.)
prvA = prv82 + &4A ; SFTODO: tweak name!
prvB = prv82 + &4B ; SFTODO: tweak name!
prvBA = prvA ; SFTODO: prvA and prvB together treated as a 16-bit value with high byte in prvB
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
prvDesiredTubeState = prv83 + &40 ; b7 set iff we want the tube on (*not* always 0 or &FF)
prvTubeOnOffInProgress = prv83 + &41 ; &FF if we're turning tube on or off, 0 otherwise
prvTubeReleasePending = prv83 + &42 ; used during OSWORD 42; &FF means we have claimed the tube and need to release it at end of transfer, 0 means we don't
; prvLastFilingSystem is used to track the last filing system selected, so we can preserve the current filing system on a soft reset.
prvLastFilingSystem = prv83 + &43
; SFTODO: If private RAM is battery backed, could we just keep OSMODE in
; prvOsMode and not bother with the copy in the low bits of userRegOsModeShx?
; That would save some code.
prvRtcUpdateEndedOptions = prv83 + &44
	prvRtcUpdateEndedOptionsGenerateUserEvent = 1<<0
	prvRtcUpdateEndedOptionsGenerateServiceCall = 1<<1

prvSetPrinterTypePending = prv83 + &49 ; Flag used to ensure *FX5 is only set on power up or hard break.

prvIbosBankNumber = prv83 + &00 ; SFTODO: not sure about this, but service01 seems to set this
prvPseudoBankNumbers = prv83 + &08 ; 4 bytes, absolute RAM bank number for the Pseudo RAM banks W, X, Y, Z; SFTODO: may be &FF indicating "no such bank" if SRSET is used?
prvSrDataBanks = prv83 + &0C ; 4 bytes, absolute RAM bank numbers for pseudo-addressing (*SRDATA), padded with &FF if less than 4 banks
prvRomTypeTableCopy = prv83 + &2C ; 16 bytes

; prvLastScreenMode is the last screen mode selected. This differs from currentMode because a)
; it includes the shadow flag in bit 7 b) it isn't modified by the OS on reset. We use it to
; emulate Master-like behaviour by preserving the current mode across a soft break. SFTODO: I
; am 95% sure this is right, but be good to check all code using it later.
prvLastScreenMode = prv83 + &3F

; We take advantage of some unofficial OS 1.20 entry points; since IBOS only needs to run on
; the Model B this is fine. SQUASH: Any prospect of taking this further? Tastefully of course!
LDC16       = &DC16
osStxRomselAndCopyAndRts = &DC16 ; STX romselCopy:STX romsel:RTS in OS 1.20
osEntryClcOsbyteEnterLanguage = &DBE6 ; CLC then enter OSBYTE 142 in OS 1.20
osEntryOsbyteIssueServiceRequest = &F168 ; start of OSBYTE 143 in OS 1.20
osReturnFromRom = &FF89
LF16E       = &F16E

bufNumKeyboard = 0
bufNumPrinter = 3 ; OS buffer number for the printer buffer

eventNumUser = 9

opcodeBitAbsolute = &2C
opcodeJmpAbsolute = &4C
opcodeRts = &60
opcodeJmpIndirect = &6C
opcodeCmpAbs = &CD
opcodeLdaImmediate = &A9
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

RomTypeService = 1 << 7
RomTypeLanguage = 1 << 6
RomType6502 = 2

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

; SFTODO: Document? Use? Delete?
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

; Helper macro for copying a block of code assembled in main RAM (at the address it will
; actually run at) into the ROM.
MACRO RELOCATE From, To
    ASSERT To >= &8000 ; sanity check
    ASSERT P% - From <= 256 ; sanity check
    COPYBLOCK From, P%, To
    CLEAR From, P%
    ORG To + (P% - From)
ENDMACRO

start = &8000
end = &C000
ORG start
GUARD end

.RomHeader
    JMP language
    JMP service
.RomType
    EQUB RomTypeService OR RomTypeLanguage OR RomType6502
.CopyrightOffset
    EQUB Copyright - RomHeader
; All versions before 1.27 have a binary version number of &FF, so I suggest we start at 0 for
; 1.27 and increment this by one each time. This gives us the maximum headroom for new versions
; and may be useful to allow user programs to test the IBOS version with if they need a specific
; feature or fix.
IF IBOS_VERSION < 127
    EQUB &FF ; binary version number
ELIF IBOS_VERSION == 127
    EQUB 0 ; binary version number
ELSE
    ; We could do EQUB IBOS_VERSION-127 but it feels safest to be explicit, in case we end up
    ; having IBOS 2.00 at some point with IBOS_VERSION == 200.
    ERROR "Need to specify binary version number explicitly"
ENDIF
.Title
    EQUS "IBOS", 0
IF IBOS_VERSION == 120
    EQUS "1.20" ; version string
ELIF IBOS_VERSION == 121
    EQUS "1.21" ; version string
ELIF IBOS_VERSION == 122
    EQUS "1.22" ; version string
ELIF IBOS_VERSION == 123
    EQUS "1.23" ; version string
ELIF IBOS_VERSION == 124
    EQUS "1.24" ; version string
ELIF IBOS_VERSION == 125
    EQUS "1.25" ; version string
ELIF IBOS_VERSION == 126
    EQUS "1.26" ; version string
ELIF IBOS_VERSION == 127
    ; TODO: We could pull the "1" prefix on all the version strings out into a separate EQUS,
    ; so we can just check INCLUDE_APPEND once instead of having to duplicate it for each
    ; version.
    IF INCLUDE_APPEND
        EQUS "1.27" ; version string
    ELSE
        EQUS "X.27" ; version string
    ENDIF
ENDIF
.Copyright
    EQUS 0, "(C)"
ComputechStart = P% + 1
IF IBOS_VERSION == 120
    EQUS " Computech"
.ComputechEnd
    EQUS " 1989", 0
ELSE
IF IBOS_VERSION < 126
    EQUS " BBC Micro "
ENDIF
ComputechEnd = P% - 1
IF IBOS_VERSION == 121
    EQUS "2019", 0
ELIF IBOS_VERSION == 122
    EQUS "2021", 0
ELIF IBOS_VERSION < 127
    EQUS "2022", 0
ELSE
    EQUS "2024", 0
ENDIF
ENDIF

;Store *Command reference table pointer address in X & Y
.CmdRef
{
    LDX #lo(CmdRef):LDY #hi(CmdRef)
    RTS
		
IF IBOS_VERSION < 127
		EQUS &20								;Number of * commands.
ELSE
		EQUS &22
ENDIF
		ASSERT P% = CmdRef + KeywordTableOffset
		EQUW CmdTbl							;Start of * command table
		ASSERT P% = CmdRef + ParameterTableOffset
		EQUW CmdParTbl							;Start of * command parameter table
IF IBOS_VERSION < 126
		ASSERT P% = CmdRef + CmdTblPtrOffset
		EQUW CmdExTbl							;Start of * command execute address table
ENDIF

;* commands
.CmdTbl
    EQUS &06, "ALARM"
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
IF IBOS_VERSION < 127
.CmdParTbl
    EQUS &09, "(", &A6, "(R))/", &A1    ;Parameter &80 for *ALARM:      '((=<TIME>(R))/ON/OFF/?)'
    EQUS &04, "(" ,&A7, ")"             ;Parameter &81 for *CALENDAR:   '(<DATE>)'
    EQUS &07, "((=)", &A7, ")"          ;Parameter &82 for *DATE:       '((=)<DATE>)'
    EQUS &03, &A6, ")"                  ;Parameter &83 for *TIME:       '(=<TIME>)'
    EQUS &06, &85, "(,", &A8,&AD        ;Parameter &84 for *CONFIGURE:  '(<par>)(,<par>)...'
    EQUS &04, "(", &A8, ")"             ;Parameter &85 for *STATUS:     '(<par>)'
    EQUS &02, &94                       ;Parameter &86 for *CSAVE:      '<fsp>'
    EQUS &02, &94                       ;Parameter &87 for *CLOAD:      '<fsp>'
    EQUS &08, "(<cmd>", &A0             ;Parameter &88 for *BOOT:       '(<cmd>/?)'
    EQUS &06, &AF, "/#" , &98, &A0      ;Parameter &89 for *BUFFER:     '(<0-4>/#<id>(,<id>).../?)'
    EQUS &03, "(", &A1                  ;Parameter &8A for *PURGE:      '(ON/OFF/?)'
    EQUS &03, &98,&A2                   ;Parameter &8B for *INSERT:     '<id>(,<id>)...(I)'
    EQUS &03, &98,&A2                   ;Parameter &8C for *UNPLUG:     '<id>(,<id>)...(I)'
    EQUS &01                            ;Parameter &8D for *ROMS:
    EQUS &03, &AF,&A0                   ;Parameter &8E for *OSMODE:     '(<0-4>/?)'
    EQUS &07, "(", &AE, "1>", &A0, ")"  ;Parameter &8F for *SHADOW:     '((<0-1>/?))'
    EQUS &03, "(", &A1                  ;Parameter &90 for *SHX:        '(ON/OFF/?)'
    EQUS &03, "(", &A1                  ;Parameter &91 for *TUBE:       '(ON/OFF/?)'
    EQUS &03, "<", &AA                  ;Parameter &92 for *GOIO:       '<addr>'
    EQUS &01                            ;Parameter &93 for *NLE:
    EQUS &06, "<fsp>"                   ;Parameter &94:                 '<fsp>'
    EQUS &04, &94, " ", &AC             ;Parameter &95:                 '<fsp> <len>'
    EQUS &02, &94                       ;Parameter &96:                 '<fsp>'
    EQUS &02, &94                       ;Parameter &97:                 '<fsp>'
    EQUS &06, &A5, "(,", &A5, &AD       ;Parameter &98:                 '<id>(,<id>)...'
    EQUS &02, &98                       ;Parameter &99:                 '<id>(,<id>)...'
    EQUS &02, &98                       ;Parameter &9A:                 '<id>(,<id>)...'
    EQUS &04, "(", &98, &A0             ;Parameter &9B:                 '(<id>(,<id>).../?)'
    EQUS &05, &94, &AB, &A3, &A2        ;Parameter &9C:                 '<fsp> <sraddr> (<id>) (Q)(I)'
    EQUS &05, &94, &AB, &A9, &A3        ;Parameter &9D:                 '<fsp> (<end>/+<len>) (<id>) (Q)'
    EQUS &06, "<", &AA, &A9, &AB, &A4   ;Parameter &9E:                 '<addr> (<end>/+<len>) <sraddr> (<id>)'
    EQUS &02, &9E                       ;Parameter &9F:                 '<addr> (<end>/+<len>) <sraddr> (<id>)'
    EQUS &04, "/?)"                     ;Parameter &A0:                 '/?)'
    EQUS &08, "ON/OFF", &A0             ;Parameter &A1:                 'ON/OFF/?)'
    EQUS &04, "(I)"                     ;Parameter &A2:                 '(I)'
    EQUS &06, &A4," (Q)"                ;Parameter &A3:                 ' (<id>) (Q)'
    EQUS &05, " (", &A5, ")"            ;Parameter &A4:                 ' (<id>)'
    EQUS &05, "<id>"                    ;Parameter &A5:                 '<id>'
    EQUS &09, "(=<time>"                ;Parameter &A6:                 '(=<time>'
    EQUS &07, "<date>"                  ;Parameter &A7:                 '<date>'
    EQUS &06, "<par>"                   ;Parameter &A8:                 '<par>'
    EQUS &0C, " (<end>/+", &AC, ")"     ;Parameter &A9:                 ' (<end>/+<len>)'
    EQUS &06, "addr>"                   ;Parameter &AA:                 'addr>'
    EQUS &06, " <sr", &AA               ;Parameter &AB:                 ' <sraddr>'
    EQUS &06, "<len>"                   ;Parameter &AC:                 '<len>'
    EQUS &05, ")..."                    ;Parameter &AD:                 ')...'
    EQUS &05, "(<0-"                    ;Parameter &AE:                 '(<0-'
    EQUS &04, &AE, "4>"                 ;Parameter &AF:                 '(<0-4>'
ELSE
.CmdParTbl
    EQUS &09, "(", &A8, "(R))/", &A3    ;Parameter &80 for *ALARM:      '((=<TIME>(R))/ON/OFF/?)'
    EQUS &04, "(" ,&A9, ")"             ;Parameter &81 for *CALENDAR:   '(<DATE>)'
    EQUS &07, "((=)", &A9, ")"          ;Parameter &82 for *DATE:       '((=)<DATE>)'
    EQUS &03, &A8, ")"                  ;Parameter &83 for *TIME:       '(=<TIME>)'
    EQUS &06, &85, "(,", &AA,&AF        ;Parameter &84 for *CONFIGURE:  '(<par>)(,<par>)...'
    EQUS &04, "(", &AA, ")"             ;Parameter &85 for *STATUS:     '(<par>)'
    EQUS &02, &94                       ;Parameter &86 for *CSAVE:      '<fsp>'
    EQUS &02, &94                       ;Parameter &87 for *CLOAD:      '<fsp>'
    EQUS &08, "(<cmd>", &A2             ;Parameter &88 for *BOOT:       '(<cmd>/?)'
    EQUS &06, &B1, "/#" , &98, &A2      ;Parameter &89 for *BUFFER:     '(<0-4>/#<id>(,<id>).../?)'
    EQUS &03, "(", &A4                  ;Parameter &8A for *PURGE:      '(ON/OFF/?)'
    EQUS &03, &98,&A4                   ;Parameter &8B for *INSERT:     '<id>(,<id>)...(I)'
    EQUS &03, &98,&A4                   ;Parameter &8C for *UNPLUG:     '<id>(,<id>)...(I)'
    EQUS &01                            ;Parameter &8D for *ROMS:
    EQUS &03, &B1,&A2                   ;Parameter &8E for *OSMODE:     '(<0-4>/?)'
    EQUS &07, "(", &B0, "1>", &A2, ")"  ;Parameter &8F for *SHADOW:     '((<0-1>/?))'
    EQUS &03, "(", &A3                  ;Parameter &90 for *SHX:        '(ON/OFF/?)'
    EQUS &03, "(", &A3                  ;Parameter &91 for *TUBE:       '(ON/OFF/?)'
    EQUS &03, "<", &AC                  ;Parameter &92 for *GOIO:       '<addr>'
    EQUS &01                            ;Parameter &93 for *NLE:
    EQUS &06, "<fsp>"                   ;Parameter &94:                 '<fsp>'
    EQUS &04, &94, " ", &AE             ;Parameter &95:                 '<fsp> <len>'
    EQUS &02, &94                       ;Parameter &96:                 '<fsp>'
    EQUS &02, &94                       ;Parameter &97:                 '<fsp>'
    EQUS &06, &A7, "(,", &A7, &AF       ;Parameter &98:                 '<id>(,<id>)...'
    EQUS &02, &98                       ;Parameter &99:                 '<id>(,<id>)...'
    EQUS &02, &98                       ;Parameter &9A:                 '<id>(,<id>)...'
    EQUS &04, "(", &98, &A2             ;Parameter &9B:                 '(<id>(,<id>).../?)'
    EQUS &05, &94, &AD, &A5, &A4        ;Parameter &9C:                 '<fsp> <sraddr> (<id>) (Q)(I)'
    EQUS &05, &94, &AD, &AB, &A5        ;Parameter &9D:                 '<fsp> (<end>/+<len>) (<id>) (Q)'
    EQUS &06, "<", &AC, &AB, &AD, &A6   ;Parameter &9E:                 '<addr> (<end>/+<len>) <sraddr> (<id>)'
    EQUS &02, &9E                       ;Parameter &9F:                 '<addr> (<end>/+<len>) <sraddr> (<id>)'
    EQUS &03, &98, &B2                  ;Parameter &A0:                 '<id>(,<id>)... (T)'
    EQUS &03, &98, &B2                  ;Parameter &A1:                 '<id>(,<id>)... (T)'
    EQUS &04, "/?)"                     ;Parameter &A2:                 '/?)'
    EQUS &08, "ON/OFF", &A2             ;Parameter &A3:                 'ON/OFF/?)'
    EQUS &04, "(I)"                     ;Parameter &A4:                 '(I)'
    EQUS &06, &A6," (Q)"                ;Parameter &A5:                 ' (<id>) (Q)'
    EQUS &05, " (", &A7, ")"            ;Parameter &A6:                 ' (<id>)'
    EQUS &05, "<id>"                    ;Parameter &A7:                 '<id>'
    EQUS &09, "(=<time>"                ;Parameter &A8:                 '(=<time>'
    EQUS &07, "<date>"                  ;Parameter &A9:                 '<date>'
    EQUS &06, "<par>"                   ;Parameter &AA:                 '<par>'
    EQUS &0C, " (<end>/+", &AE, ")"     ;Parameter &AB:                 ' (<end>/+<len>)'
    EQUS &06, "addr>"                   ;Parameter &AC:                 'addr>'
    EQUS &06, " <sr", &AC               ;Parameter &AD:                 ' <sraddr>'
    EQUS &06, "<len>"                   ;Parameter &AE:                 '<len>'
    EQUS &05, ")..."                    ;Parameter &AF:                 ')...'
    EQUS &05, "(<0-"                    ;Parameter &B0:                 '(<0-'
    EQUS &04, &B0, "4>"                 ;Parameter &B1:                 '(<0-4>'
    EQUS &05, " (T)"                    ;Parameter &B2:                 ' (T)'
ENDIF

;lookup table for start address of recognised * commands
.^CmdExTbl
    EQUW alarm-1                        ;address of *ALARM command
    EQUW calend-1                       ;address of *CALENDAR command
    EQUW date-1                         ;address of *DATE command
    EQUW time-1                         ;address of *TIME command
    EQUW config-1                       ;address of *CONFIGURE command
    EQUW status-1                       ;address of *STATUS command
    EQUW csave-1                        ;address of *CSAVE command
    EQUW cload-1                        ;address of *CLOAD command
    EQUW boot-1                         ;address of *BOOT command
    EQUW buffer-1                       ;address of *BUFFER command
    EQUW purge-1                        ;address of *PURGE command
    EQUW insert-1                       ;address of *INSERT command
    EQUW unplug-1                       ;address of *UNPLUG command
    EQUW roms-1                         ;address of *ROMS command
    EQUW osmode-1                       ;address of *OSMODE command
    EQUW shadow-1                       ;address of *SHADOW command
    EQUW shx-1                          ;address of *SHX command
    EQUW tube-1                         ;address of *TUBE command
    EQUW goio-1                         ;address of *GOIO command
    EQUW nle-1                          ;address of *NLE command
    EQUW append-1                       ;address of *APPEND command
    EQUW create-1                       ;address of *CREATE command
    EQUW print-1                        ;address of *PRINT command
    EQUW SpoolOn-1                      ;address of *SPOOLON command
    EQUW srwipe-1                       ;address of *SRWIPE command
    EQUW srdata-1                       ;address of *SRDATA command
    EQUW srrom-1                        ;address of *SRROM command
    EQUW srset-1                        ;address of *SRSET command
    EQUW srload-1                       ;address of *SRLOAD command
    EQUW srsave-1                       ;address of *SRSAVE command
    EQUW srread-1                       ;address of *SRREAD command
    EQUW srwrite-1                      ;address of *SRWRITE command
    EQUW srwe-1                         ;address of *SRWE command
    EQUW srwp-1                         ;address of *SRWP command
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
    ;     n, char 1, 2, ..., n-1           i  ConfTbl entry  fully expanded text
IF IBOS_VERSION < 126
    EQUB  7, t+1, "(D/N)"               ;  0  FILE           "<0-15>(D/N)"
    EQUB  5, t+19, "15>"                ;  1  LANG           "<0-15>"
ELSE
    EQUB  7, t+20, "(D/N)"              ;  0  FILE           "<0-15>(D/N)"
    EQUB  6, t+20, "(,", t+20, ")"      ;  1  LANG           "<0-15>(,<0-15>)"
ENDIF
    EQUB  6, "<1-8>"                    ;  2  BAUD           "<1-8>"
    EQUB  4, t+19, "7>"                 ;  3  DATA           "<0-7>"
    EQUB  2, t+3                        ;  4  FDRIVE         "<0-7>"
    EQUB  4, t+19, "4>"                 ;  5  PRINTER        "<0-4>"
    EQUB  6, t+19, "255>"               ;  6  IGNORE         "<0-255>"
    EQUB  2, t+6                        ;  7  DELAY          "<0-255>"
    EQUB  2, t+6                        ;  8  REPEAT         "<0-255>"
    EQUB  7, t+17, t+18, "/SH", t+18    ;  9  CAPS           "/NOCAPS/SHCAPS"
    EQUB  6, t+6, ",", t+19, "1>"       ; 10  TV             "<0-255>,<0-1>"
    EQUB 14, "(", t+4, "/<128-135>)"    ; 11  MODE           "(<0-7>/<128-135>)"
    EQUB  6, t+17, "TUBE"               ; 12  TUBE           "/NOTUBE"
    EQUB  6, t+17, "BOOT"               ; 13  BOOT           "/NOBOOT"
    EQUB  5, t+17, "SHX"                ; 14  SHX            "/NOSHX"
    EQUB  2, t+5                        ; 15  OSMODE         "<0-4>"
    EQUB  5, t+19, "63>"                ; 16  ALARM          "<0-63>"
    EQUB  4, "/NO"                      ; 17  -              "/NO"
    EQUB  5, "CAPS"                     ; 18  -              "CAPS"
    EQUB  4, "<0-"                      ; 19  -              "<0-"
IF IBOS_VERSION >= 126
    EQUB  5, t+19, "15>"                ; 20  -              "<0-15>"
ENDIF
    EQUB  0
}

;Store IBOS Options reference table pointer address in X & Y
.ibosRef
{
    LDX #lo(ibosRef):LDY #hi(ibosRef)
    RTS

    EQUB &04								;Number of IBOS options
    ASSERT P% = ibosRef + KeywordTableOffset
    EQUW ibosTbl								;Start of IBOS options lookup table
    ASSERT P% = ibosRef + ParameterTableOffset
    EQUW ibosParTbl								;Start of IBOS options parameters lookup table (there are no parameters!)
IF IBOS_VERSION < 126
    ; SQUASH: I am not sure we actually need the next pointer, if we make the suggested SQUASH:
    ; change in DynamicSyntaxGenerationForIbosHelpTableA.
    ASSERT P% = ibosRef + CmdTblPtrOffset
    EQUW ibosHelpTable							;Start of IBOS sub option reference lookup table
ENDIF

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

}
.ibosHelpTable
    ; Elements 0-3 of ibosHelpTable table correspond to the four entries at ibosTbl.
    ibosHelpTableHelpNoArgument = 4
    ibosHelpTableConfigureList = 5
    EQUW CmdRef:EQUB &00,&03							;&04 x IBOS/RTC Sub options - from offset &00
    EQUW CmdRef:EQUB &04,&13							;&10 x IBOS/SYS Sub options - from offset &04
    EQUW CmdRef:EQUB &14,&17							;&04 x IBOS/FSX Sub options - from offset &14
IF IBOS_VERSION < 127
    EQUW CmdRef:EQUB &18,&1F							;&08 x IBOS/SRAM Sub options - from offset &18
ELSE
    EQUW CmdRef:EQUB &18,&21							;&0A x IBOS/SRAM Sub options - from offset &18
ENDIF
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
    STX transientTblPtr
    STA transientTblPtr + 1
    ; Decrement transientCmdPtr by 1 to compensate for using 1-based Y in the following loop.
IF IBOS_VERSION < 126
    SEC:LDA transientCmdPtr:SBC #1:STA transientCmdPtr
    DECCC transientCmdPtr + 1
ELSE
    ; Decrement by one technique from http://www.obelisk.me.uk/6502/algorithms.html
    LDA transientCmdPtr:BNE NoBorrow
    DEC transientCmdPtr + 1
.NoBorrow
    DEC transientCmdPtr
ENDIF
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
IF IBOS_VERSION < 127
    JMP CharacterMatchLoop
ELSE
    BNE CharacterMatchLoop ; always branch
ENDIF
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

IF IBOS_VERSION < 126
    ; This code is needlessly complicated; it is probably a legacy of an earlier version where
    ; this didn't just operate on ibosRef - note that some callers redundantly call "JSR
    ; ibosRef" before calling this subroutine.

    ; Set transientTblPtr = transientTblPtr[CmdTblPtrOffset].
    JSR ibosRef:STX transientTblPtr:STY transientTblPtr + 1
    LDY #CmdTblPtrOffset:LDA (transientTblPtr),Y:TAX
    INY:LDA (transientTblPtr),Y:STA transientTblPtr + 1
    STX transientTblPtr

    ; Copy the the four bytes starting at ibosHelpTable+4*A-on-entry into transientTblPtr and
    ; FirstEntry/LastEntry.
    PLA:PHA:ASL A:ASL A:TAY ; Set Y = A-on-entry * 4
    LDA (transientTblPtr),Y:PHA
    INY:LDA (transientTblPtr),Y:PHA
    INY:LDA (transientTblPtr),Y:STA FirstEntry
    INY:LDA (transientTblPtr),Y:STA LastEntry
    PLA:STA transientTblPtr + 1
    PLA:STA transientTblPtr
ELSE
    ASL A:ASL A:TAY
    LDA ibosHelpTable    ,Y:STA transientTblPtr
    LDA ibosHelpTable + 1,Y:STA transientTblPtr + 1
    LDA ibosHelpTable + 2,Y:STA FirstEntry
    LDA ibosHelpTable + 3,Y:STA LastEntry
ENDIF

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
;     V set => don't emit parameters or carriage return
;     V clear => emit parameters then carriage return
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
IF IBOS_VERSION < 126
    LDA TableEntryPtr + 1:ADC #0:STA TableEntryPtr + 1
ELSE
    INCCS TableEntryPtr + 1
ENDIF
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
IF IBOS_VERSION < 126
    BIT transientDynamicSyntaxState
ELSE
    ; V hasn't been modified since we entered this routine.
ENDIF
    BVS NoLeadingSpaces
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
IF IBOS_VERSION < 126
    LDA (transientCmdPtr),Y
ENDIF
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
IF IBOS_VERSION < 127
    LDA #4 ; redundant, ExitServiceCall will do PLA
ENDIF
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
if IBOS_VERSION < 126
    ; Transfer control to CmdRef[CmdTblPtrOffset][X], preserving Y (the index into the next
    ; byte of the command tail after the * command).
    STY TmpCommandTailOffset
    STX TmpCommandIndex
    ; Set transientTblPtr = CmdRef[CmdTblPtrOffset].
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
    ; this here directly.
    LDX TmpCommandIndex:STX transientCommandIndex
ELSE
    ; Transfer control to CmdExTbl[X], preserving Y (the index into the next byte of the command
    ; tail after the * command).
    STY TmpCommandTailOffset
    STX transientCommandIndex ; used later when generating a syntax error if necessary
    TXA:ASL A:TAY
    LDA CmdExTbl+1,Y:PHA
    LDA CmdExTbl  ,Y:PHA
ENDIF
    LDY TmpCommandTailOffset
    RTS ; transfer control to the command
}

;*HELP Service Call
; ENHANCE: IBOS doesn't print everything in response to "*HELP ."
; ENHANCE: IBOS doesn't print in response to things like "*HELP DFS RTC"
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
    LDX #Title - RomHeader
.TitleVersionLoop
    LDA RomHeader,X:BNE PrintChar
    LDA #' ' ; convert 0 bytes in ROM header to spaces
.PrintChar
    JSR OSWRCH
    INX:CPX CopyrightOffset:BNE TitleVersionLoop
    JSR OSNEWL
    ; Now show the selected ibosRefSubTblA entry.
    PLA
IF IBOS_VERSION < 126
    JSR ibosRef
ENDIF
    JSR DynamicSyntaxGenerationForIbosHelpTableA
    JMP ExitServiceCallIndirect

.CheckArgument
    ; This is *HELP with an argument; see if we recognise the argument and show it if we do.
    JSR ibosRef:LDA #0:JSR SearchKeywordTable:BCC ShowHelpX
.ExitServiceCallIndirect
    JMP ExitServiceCall
}

IF IBOS_VERSION < 127
; Return with A=Y=0 and (transientCmdPtr),Y accessing the same byte as (osCmdPtr),Y on entry.
.SetTransientCmdPtr
    CLC:TYA:ADC osCmdPtr:STA transientCmdPtr
    LDA osCmdPtr + 1:ADC #0:STA transientCmdPtr + 1
    LDA #0:TAY
    RTS
ENDIF

.GenerateSyntaxErrorForTransientCommandIndex
    PRVDIS
    LDA transientCommandIndex
    JSR CmdRef
    SEC
IF IBOS_VERSION >= 125
    ; Earlier versions of IBOS just used whatever happened to be in V - often the result of
    ; ConvertIntegerDefaultDecimal or similar - which meant that whether the parameters were
    ; included in the error message was a bit arbitrary. We always want to show them.
    CLV
ENDIF
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
IF IBOS_VERSION < 127
    TSX:LDA #0:STA L0103,X ; set stacked A to 0 to claim the call
    JMP ExitServiceCall
ELSE
    PLA:TAY:PLA:TAX:PLA:LDA #0:RTS
ENDIF
.CallHandlerX
    ; SQUASH: If we split the handler table into low and high tables we could
    ; possibly save three bytes by no longer needing to double X. This assumes
    ; none of the handler subroutines use the value in X on entry.
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

; Generate an error using the error number and error string immediately following the "JSR
; RaiseError" call.
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
IF IBOS_VERSION < 127
    LDA (transientCmdPtr),Y ; Redundant. Included in JSR FindNextCharAfterSpace
ENDIF
    AND #CapitaliseMask:CMP #'O':BNE Invalid
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
			
IF IBOS_VERSION < 127 
; Print A in decimal. C set on entry means no padding, C clear means right align with spaces in
; a three character field. A and Y are preserved.
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

    LDX #0
    SEC
.HundredsLoop
    SBC #100
    INX
    BCS HundredsLoop
    ADC #100
    JSR PrintDigit

    LDX #0
    SEC
.TensLoop
    SBC #10
    INX
    BCS TensLoop
    ADC #10
    JSR PrintDigit

    TAX
    INX
    DEC PadFlag
    JSR PrintDigit
    PLA
    RTS
			
.PrintDigit
    PHA
    DEX
    LDA Pad
    CPX #0
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

ELSE

; Print A in decimal. C set on entry means no padding, C clear means right align with spaces in
; a three character field. A and Y are preserved.
; SQUASH: If it helps, we could probably corrupt Y and change the callers - the only one I
; actively know of is at ShowBankLoop - to not rely on it.
.PrintADecimal
{
Pad = &B0		;character output in place of leading zeros
PadFlag = &B1	;b7 clear iff "0" should be converted into "Pad"

    LDX #&00		;Entry point for 8 bit binary conversion
    STX transientBin+1

.^PrintAbcd16Decimal
    PHA		;Entry point for 16 bit binary conversion
    STA transientBin+0
    LDA #&00
    STA transientBCD+0
    STA transientBCD+1

    STA PadFlag		;When &B1 is set to 0, any printable zeros should be considered leading and should be replaced with either a padding space or nothing (defined by contents of &B0)
    BCS NoPadding		;If carry set, don't pad in place of leading zero (print chr$0)
    LDA #' '		;Otherwise add padding space in place of leading zeros(print chr$32)
.NoPadding
    STA Pad		;Padding space ascii value stored at &B0

    SED			;Switch to decimal mode
    LDX #&10		;The number of source bits
.cnvbit
    ASL transientBin+0	;Shift out one bit
    ROL transientBin+1
    LDA transientBCD+0	;And add into result
    ADC transientBCD+0
    STA transientBCD+0
    LDA transientBCD+1	;propagating any carry
    ADC transientBCD+1
    STA transientBCD+1
    DEX			;And repeat for next bit
    BNE cnvbit
    CLD			;Back to binary

    JSR PrintDigitInA		;Print 100s
    LDA transientBCD
    LSR A
    LSR A
    LSR A
    LSR A
    JSR PrintDigitInA		;Print 10s
    DEC PadFlag		;Do not pad units if value is 0
    LDA transientBCD
    AND #&0F
    JSR PrintDigitInA		;Print 1s
    PLA
    RTS

.PrintDigitInA
    TAX ; SQUASH: optimisable?
    LDA Pad
    CPX #0
    BNE NotZero
    BIT PadFlag:BPL PrintPad
.NotZero
    DEC PadFlag
    TXA:ORA #'0'
.PrintPad
    JMP OSWRCH
}
ENDIF
		
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
;     1 1 => input not empty but nothing was parsed (v1.24 and earlier will have beeped)
;            ConvertIntegerResult and A will be 0 but flags will not reflect A
;
; SQUASH: Could we use some loops to do the four byte arithmetic?
{
Tmp = FilingSystemWorkspace + 4 ; 4 bytes
Base = FilingSystemWorkspace + 8
NegateFlag = FilingSystemWorkspace + 9
OriginalCmdPtrY = FilingSystemWorkspace + 10
FirstDigitCmdPtrY = FilingSystemWorkspace + 11

.^ConvertIntegerDefaultHex
    LDA #16
IF IBOS_VERSION < 127
    JMP ConvertIntegerDefaultBaseA
ELSE
    ; Jump to ConvertIntegerDefaultBaseA using BIT absolute to skip the next two bytes. This
    ; won't access I/O addresses as its operand high byte is 10.
    EQUB opcodeBitAbsolute
    ASSERT ConvertIntegerDefaultBaseA = P% + 2
ENDIF

IF IBOS_VERSION < 127
.NothingToConvert
    ; Carry is already set
    CLV
    RTS
ENDIF

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
    LDA #10
IF IBOS_VERSION < 127
    JMP BaseInA
ELSE
    BNE BaseInA ; always branch
ENDIF
.NotNegative
    ; Check for prefixes which indicate a particular base, overriding the default.
    CMP #'+':BEQ Decimal
    CMP #'&':BNE NotHex
    LDA #16
IF IBOS_VERSION < 127
    JMP BaseInA
ELSE
    BNE BaseInA ; always branch
ENDIF
.NotHex
    CMP #'%':BNE ParseDigit
    LDA #2
.BaseInA
    STA Base
    INY:STY FirstDigitCmdPtrY
    JMP ParseDigit ; SQUASH: "BNE ; always branch"?

IF IBOS_VERSION >= 127
; SQUASH: Could we share this fragment?
.NothingToConvert
    ; Carry is already set
    CLV
    RTS
ENDIF
			
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
IF IBOS_VERSION <= 124
    ; Beeping here is a bit odd (* command parsing errors don't normally beep), and as
    ; bugs/quirks in the error generation are fixed in 1.25 we don't really need it any more.
    LDA #vduBell:JSR OSWRCH
ENDIF
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
IF IBOS_VERSION < 127
    PHA ; redundant as we're going to return a value in A anyway
ENDIF
    CLC:TXA:ADC #rtcUserBase:TAX
IF IBOS_VERSION < 127
    PLA
ENDIF
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
; SQUASH: As we don't currently fall through into this, we could move the most common LDA/LDX
; instruction immediately before it and then share that instruction.
.^WritePrivateRam8300X
    PHP:SEI
    JSR SwitchInPrivateRAM
    STA prv83,X
IF IBOS_VERSION < 127
    PHA
ENDIF
    JMP SwitchOutPrivateRAM

; Page in private RAM temporarily and do LDA prv83,X. X and Y are preserved, flags reflect A
; on exit.
.^ReadPrivateRam8300X
    PHP:SEI
    JSR SwitchInPrivateRAM
    LDA prv83,X
IF IBOS_VERSION < 127
    PHA
    JMP SwitchOutPrivateRAM
ELSE
    FALLTHROUGH_TO SwitchOutPrivateRAM

; This is *not* a subroutine; it expects to PLA:PLP values stacked by the caller.
.SwitchOutPrivateRAM
    PHA
    ; SFTODO: See SwitchInPrivateRAM; are we taking a chance here with NMIs?
    LDA romselCopy:STA romsel
    LDA ramselCopy:STA ramsel
    PLA
    PLP
    PHA:PLA ; make flags reflect value in A on exit
    RTS
ENDIF

.SwitchInPrivateRAM
    PHA
    ; SFTODO: Shouldn't we be updating ramselCopy and (especially) romselCopy here? I know we
    ; have interrupts disabled but is there no risk of an NMI? See
    ; https://stardot.org.uk/forums/viewtopic.php?f=54&t=22552.
    LDA ramselCopy:AND #ramselShen:ORA #ramselPrvs1:STA ramsel
    LDA romselCopy:ORA #romselPrvEn:STA romsel
    PLA
    RTS

IF IBOS_VERSION < 127
; This is *not* a subroutine; it expects to PLA:PLP values stacked by the caller.
.SwitchOutPrivateRAM
    ; SFTODO: See SwitchInPrivateRAM; are we taking a chance here with NMIs?
    LDA romselCopy:STA romsel
    LDA ramselCopy:STA ramsel
    PLA
    PLP
    PHA:PLA ; make flags reflect value in A on exit
    RTS
ENDIF
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
{
IF IBOS_VERSION < 127
.^language
    ; Check this is normal language start up, not (e.g.) Electron soft key expansion.
    CMP #1:BEQ NormalLanguageStartUp
    RTS
ENDIF

;Set BRK Vector
.^setBrkv
    LDA #lo(BrkvHandler):STA BRKVL
    LDA #hi(BrkvHandler):STA BRKVH
.Rts
    RTS

; SFTODO: Start of this code is same as L8969 - could we save a few bytes by (e.g.) setting osErrorPtr to &8000 here and testing for that in BRKV handler and skipping the error printing code in that case?
IF IBOS_VERSION < 127
.NormalLanguageStartUp
    CLI
    CLD
    LDX #&FF:TXS
    JSR setBrkv
    LDA lastBreakType:BNE NotSoftReset
    JMP CmdLoop
.NotSoftReset
    LDA #osbyteKeyboardScanFrom10:JSR OSBYTE:CPX #keycodeAt:BEQ atPressed
    JMP CmdLoop

    ; Implement IBOS reset when @ held down during (non-soft) reset.
.atPressed
    LDA #osbyteReadWriteBreakEscapeEffect:LDX #2:LDY #0:JSR OSBYTE ; Memory cleared on next reset, ESCAPE disabled
    LDX #0
.promptLoop
    LDA resetPrompt,X:BEQ promptDone
    JSR OSASCI
    INX:BNE promptLoop ; always branch
ENDIF
.promptDone
    ; Wait until @ is released, flush the keyboard buffer and read user response to prompt.
.releaseAtLoop
IF IBOS_VERSION < 127
    LDA #osbyteKeyboardScanFrom10:JSR OSBYTE
ELSE
    JSR DoOsbyteKeyboardScanFrom10
ENDIF
    CPX #keycodeAt:BEQ releaseAtLoop
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

IF IBOS_VERSION >= 127
.^language
    ; Check this is normal language start up, not (e.g.) Electron soft key expansion.
    CMP #1:BNE Rts

.NormalLanguageStartUp
    CLI
    CLD
    LDX #&FF:TXS
    JSR setBrkv
    LDA lastBreakType:BEQ CmdLoop ; branch if soft reset
IF IBOS_VERSION < 127
    LDA #osbyteKeyboardScanFrom10:JSR OSBYTE
ELSE
    JSR DoOsbyteKeyboardScanFrom10
ENDIF
    CPX #keycodeAt:BNE CmdLoop
    FALLTHROUGH_TO atPressed

    ; Implement IBOS reset when @ held down during (non-soft) reset.
.atPressed
    LDA #osbyteReadWriteBreakEscapeEffect:LDX #2:LDY #0:JSR OSBYTE ; Memory cleared on next reset, ESCAPE disabled
    LDX #0
.promptLoop
    LDA resetPrompt,X:BEQ promptDone
    JSR OSASCI
    INX:BNE promptLoop ; always branch
ENDIF

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
IF IBOS_VERSION < 127
    JSR PrintStar
ELSE
    LDA #'*':JSR OSWRCH
ENDIF
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

IF IBOS_VERSION < 127
.PrintStar
    LDA #'*':JMP OSWRCH
ENDIF

IF IBOS_VERSION >= 127
; Return with A=Y=0 and (transientCmdPtr),Y accessing the same byte as (osCmdPtr),Y on entry.
.*SetTransientCmdPtr
    CLC:TYA:ADC osCmdPtr:STA transientCmdPtr
    LDA osCmdPtr + 1:ADC #0:STA transientCmdPtr + 1
    LDA #0:TAY
.SetTransientCmdPtrRts
    RTS
ENDIF

.ReadLine
IF IBOS_VERSION < 127
    LDY #(OswordInputLineBlockEnd - OswordInputLineBlock) - 1
.CopyLoop
    LDA OswordInputLineBlock,Y:STA L0100,Y
    DEY:BPL CopyLoop
    LDA #oswordInputLine:LDX #lo(L0100):LDY #hi(L0100):JSR OSWORD
    BCS AcknowledgeEscapeAndGenerateErrorIndirect
    RTS
ELSE
    LDA #oswordInputLine:LDX #lo(OswordInputLineBlock):LDY #hi(OswordInputLineBlock):JSR OSWORD
    BCC SetTransientCmdPtrRts
    FALLTHROUGH_TO AcknowledgeEscapeAndGenerateErrorIndirect
ENDIF

.AcknowledgeEscapeAndGenerateErrorIndirect
    JMP AcknowledgeEscapeAndGenerateError
}

;Start of full reset
; SFTODO: This has only one caller
{
ptr = &00 ; 2 bytes

.^FullReset
    ; Zero user RTC registers &00-X inclusive, except the following, which are treated as a special case:
    ;  - register &05: userRegLangFile.
    ;  - registers &2F / &30: userDefaultRegBankWriteProtectStatus ***CURRENTLY DISABLED***.
    ;  - register &31: userRegPALPROMConfig (outside the range anyway).
IF IBOS_VERSION < 127
    LDX #&32
ELSE
    LDX #&30
ENDIF
.ZeroUserRegLoop
    LDA #0
IF IBOS_VERSION < 126
    CPX #userRegLangFile
    BNE NotLangFile
IF IBOS_VERSION == 120 OR IBOS_VERSION >= 124
    ; We default LANG and FILE to IBOS (i.e. the current bank); this isn't all that useful for FILE but
    ; it will give consistent results, and with IBOS as the current language we will enter the NLE so
    ; the user can issue *CONFIGURE commands.
    LDA romselCopy:ASL A:ASL A:ASL A:ASL A:ORA romselCopy
ELSE
    ; Default LANG to &E and FILE to &C.
    ; All but the last LDA instruction are redundant.
    LDA romselCopy:ASL A:ASL A:ASL A:ASL A:LDA #&EC
ENDIF
ELSE
    ; We default both of these to &FF. This will probably (if IBOS is in bank 15) cause the NLE
    ; to be entered so the user can enter *CONFIGURE commands, and with the new language entry
    ; code we will enter a valid language or NLE even if IBOS isn't in bank 15. This allows us
    ; to save a few bytes by not setting LANG/FILE to IBOS's actual bank.
    CPX #userRegLang:BEQ IsLangFile
    CPX #userRegFile:BNE NotLangFile
.IsLangFile
    LDA #&FF
ENDIF
.NotLangFile
    JSR WriteUserReg
    DEX:BPL ZeroUserRegLoop

FullResetPrv = &2800
    JSR InitialiseRtcTime
    LDX #0 ; copy 256 bytes of code/data
.CopyLoop
    LDA FullResetPrvTemplate,X:STA FullResetPrv,X
    INX:BNE CopyLoop
    JMP FullResetPrv

; This code is relocated from IBOS ROM to RAM starting at FullResetPrv
.^FullResetPrvTemplate
    ORG FullResetPrv
.^FullResetPrvCopy
    LDA romselCopy:PHA
    ; Zero all sideways RAM.
    LDX #maxBank
.ZeroSwrLoop
    STX romselCopy:STX romsel
    LDA #&80:JSR ZeroPageAUpToC0 ; SFTODO: mildly magic
    DEX:BPL ZeroSwrLoop
    ; Zero shadow/private RAM.
    LDA #ramselShen OR ramselPrvs841:STA ramselCopy:STA ramsel
    LDA #romselPrvEn:STA romselCopy:STA romsel
    LDA #&30:JSR ZeroPageAUpToC0 ; SFTODO: mildly magic
    ; Initialise prvSrDataBanks. SQUASH: SHhorten with a loop?
    LDA #&FF
    STA prvSrDataBanks + 0:STA prvSrDataBanks + 1
    STA prvSrDataBanks + 2:STA prvSrDataBanks + 3
    LDA #0:STA ramselCopy:STA ramsel
    PLA:STA romselCopy:STA romsel
    ; Set the user registers to their default values.
    ; SFTODO: I may be misreading this code, but won't it access one double-byte entry *past*
    ; UserRegDefaultTableEnd? Effectively treating PHP:SEI as a pair of bytes &08,&78? (Assuming they
    ; fit in the 256 bytes copied to main RAM.) I would have expected to write -2 on the next
    ; line not -0. Does user reg &08 get used at all? If it never gets overwritten, we could
    ; test this by seeing if it holds &78 after a reset. If I'm right, this will overwrite the
    ; 0 we wrote in ZeroUserRegLoop above.
    LDY #(UserRegDefaultTableEnd - UserRegDefaultTable) - 0
.SetDefaultLoop
    LDX UserRegDefaultTable + 0,Y
    LDA UserRegDefaultTable + 1,Y
    JSR WriteUserReg
    DEY:DEY:BPL SetDefaultLoop

;IF IBOS_VERSION >= 127
;    LDX #userDefaultRegBankWriteProtectStatus:JSR ReadUserReg
;    LDX #userRegBankWriteProtectStatus:JSR WriteUserReg
;    LDX #userDefaultRegBankWriteProtectStatus + 1:JSR ReadUserReg
;    LDX #userRegBankWriteProtectStatus + 1:JSR WriteUserReg
;ENDIF

    ; Simulate a power-on reset.
IF IBOS_VERSION < 127
    LDA #osbyteWriteSheila:LDX #systemViaBase + viaRegisterInterruptEnable:LDY #&7F:JSR OSBYTE
ELSE
    LDA #&7F:STA SHEILA + systemViaBase + viaRegisterInterruptEnable
ENDIF
    JMP (RESET)

.ZeroPageAUpToC0
    STA ptr + 1
    LDA #0:STA ptr
    TAY
.ZeroLoop
    LDA #0:STA (ptr),Y
    INY:BNE ZeroLoop
    INC ptr + 1
    LDA ptr + 1:CMP #&C0:BNE ZeroLoop
    RTS

; Default values for user registers overriding the initial zero values assigned.
.^UserRegDefaultTable
    EQUB userRegBankInsertStatus + 0, &FF     	; default to no banks unplugged
    EQUB userRegBankInsertStatus + 1, &FF 	; default to no banks unplugged
IF IBOS_VERSION == 120 OR IBOS_VERSION >= 126
    EQUB userRegModeShadowTV, &17
ELSE
    EQUB userRegModeShadowTV, &E7
ENDIF
IF IBOS_VERSION == 120 AND IBOS120_VARIANT == 0
    EQUB userRegFdriveCaps, &23
ELSE
    EQUB userRegFdriveCaps, &20
ENDIF
    EQUB userRegKeyboardDelay, &19
    EQUB userRegKeyboardRepeat, &05
    EQUB userRegPrinterIgnore, &0A
    EQUB userRegTubeBaudPrinter, &2D
IF IBOS_VERSION == 120 AND IBOS120_VARIANT == 0
    EQUB userRegDiscNetBootData, &A0
ELSE
    EQUB userRegDiscNetBootData, &A1
ENDIF
    EQUB userRegOsModeShx, &04
IF IBOS_VERSION == 120 AND IBOS120_VARIANT == 0
    EQUB userRegCentury, 19
ELSE
    EQUB userRegCentury, 20
ENDIF
IF IBOS_VERSION < 127
    EQUB userRegBankWriteProtectStatus + 0, &FF
    EQUB userRegBankWriteProtectStatus + 1, &FF
ELSE
 ; default is for banks 4..7 to be write enabled. There is no need to define
 ; userRegBankWriteProtectStatus+1 here, because the default value is '0'.
    EQUB userRegBankWriteProtectStatus + 0, &F0
;   EQUB userRegBankWriteProtectStatus + 1, &00
ENDIF
    EQUB userRegPrvPrintBufferStart, &90
IF IBOS_VERSION < 127
; userRegRamPresenceFlags is used by V1 hardware to define the total RAM in 32k chunks:
;  - bits 0..1: 64K non-SWR (base beeb)
;  - bits 2..3: 64K SWR in banks 4-7
    EQUB userRegRamPresenceFlags, &0F		; 64K non-SWR and 64K SWR in banks 4-7
ELSE
; As of IBOS 127, both V1 and V2 hardware use two registers to define the total RAM in 16k chunks
; On V1 hardware these registers need to be updated manually if extra RAM is added using *FX162
; or by using the RAMSET utility. This needs to be done after every IBOS reset, otherwise it
; will default to RAM in banks 4..7
; On V2 hardware these registers are defined by a set of jumpers on the v2 board.
; The status of these jumpers is read from the CPLD by IBOS service10 on every BREAK.
; So for V2 hardware there is no need to specifically define default values here.
; The default is retained for V1 hardware only. Note the default vaule for userRegRamPresenceFlags8_F
; is already set to '0' so doesn't need to be set here too.
    EQUB userRegRamPresenceFlags0_7, &F0	; ROMs in Banks 0-3. 16K RAM in each of banks 4-7
;   EQUB userRegRamPresenceFlags8_F, &00	; ROMs in Banks 8-15
ENDIF
.UserRegDefaultTableEnd

    ; SFTODO: USE RELOCATE
    RELOCATE FullResetPrv, FullResetPrvTemplate
    ; SFTODO: +2 because as per above SFTODO I think we actually use an extra entry off the end
    ; of this table.
    ASSERT (P% + 2) - FullResetPrvTemplate <= 256
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
IF IBOS_VERSION < 127
    TXA:STA WorkingX
ELSE
    STX WorkingX
ENDIF
    LDA ramselCopy:ROL A:PHP ; stack flags with C=ramselShen
IF IBOS_VERSION < 127
    LDA WorkingX
ELSE
    TXA
ENDIF
    AND #StackBit OR ReadBit:CMP #StackBit:BNE NotStackWrite
    PLP:PHP:ROR prvOsbyte6FStack ; push ramselShen onto the stack
IF IBOS_VERSION < 127
    LDA WorkingX
ELSE
    TXA
ENDIF
    AND_NOT StackBit OR IgnoredBits:STA WorkingX ; clear StackBit
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
    ; SFTODO: It's not correct that this returns anything other than &6F in A, but this change
    ; does make it incorrect in a different way in 1.27 onwards.
IF IBOS_VERSION < 127
    LDA ReturnedX:TAX
ELSE
    LDX ReturnedX
    LDA #&6F ; SQUASH: can we avoid the need for our OSBYTE calls to preserve A internally?
ENDIF
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
    ; CMP #0 is redundant.
    LDX #prvOsMode - prv83:JSR ReadPrivateRam8300X
IF IBOS_VERSION < 127
    CMP #0
ENDIF
    BNE osbyte6C
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
; SFTODO: Rename these labels so we have something like "CheckOsbyte49" for the test and
; "Osbyte49" for the actual "yes, now do it"? (Not just 49, all of them.)
.osbyte49
{
prvRtcUpdateEndedOptionsMask = prvRtcUpdateEndedOptionsGenerateUserEvent OR prvRtcUpdateEndedOptionsGenerateServiceCall

    CMP #&49:BEQ osbyte49Internal
    JMP ExitServiceCall

.osbyte49Internal
    ; Could we use X instead of A here? Then we'd already have &49 in A and could avoid
    ; LDA #&49.
IF IBOS_VERSION < 127
    LDA oswdbtX:CMP #&FF:BNE XNeFF
    ; It's X=&FF: test for presence of Integra-B.
    LDA #&49
ELSE
    LDX oswdbtX:CPX #&FF:BNE XNeFF
    ; It's X=&FF: test for presence of Integra-B.
ENDIF    
    STA oswdbtX ; return with X=&49 indicates Integra-B is present

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

IF IBOS_VERSION < 126
; Dead code
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
ENDIF

IF IBOS_VERSION >= 126
; OSWORD &0F (15) Write real time clock
; YX?0 is the function code, the string starts at YX+1:
;  8 - Set time to value in format "HH:MM:SS"
; 15 - Set date to value in format "Day,DD Mon Year"
; 24 - Set time and date to value in format "Day,DD Mon Year.HH:MM:SS"
;
; Parsing in here is relatively free-and-easy, but that seems to be how OS 3.20 does it as well.
; I haven't tried to emulate the behaviour of OS 3.20 when given invalid strings; all I really
; care about is that we handle valid strings correctly and invalid strings without crashing.
;
; We claim the call even if the function code is unrecognised or we fail to parse the provided
; string. I'm not completely clear what the "correct" behaviour is here, but in practice this
; should be fine.
.osword0f
{
    JSR SaveTransientZP
    PRVEN
    ; We aren't using the oswordsv/oswordrs style from other OSWORDs, in part because
    ; prvOswordBlockCopySize is only 16, which isn't large enough for OSWORD &0F.
    LDA oswdbtX:STA transientCmdPtr
    LDA oswdbtY:STA transientCmdPtr + 1
    JSR CopyRtcDateTimeToPrv
    LDY #0
    LDA (transientCmdPtr),Y
    INY ; skip function code so (transientCmdPtr),Y accesses first byte of string
    CMP #8:BEQ ParseTime
    CMP #15:BEQ ParseDate
    CMP #24:BNE Done ; branch if invalid function code
.ParseDate
    PHA
    ; Skip the three letter day of the week and the following comma, or whatever else might be
    ; there. The day of the week is at best redundant and at worst inconsistent, so we just
    ; ignore it and calculate the correct day of the week ourselves in ParseAndValidateDate.
    ; (OS 3.20 trusts the user to supply the day of the week correctly, but it would take extra
    ; code to parse it and it would only open up the possibility of it being set incorrectly.)
    INY:INY:INY:INY
    JSR ParseAndValidateDate
    PLA
    BCS Done ; branch if unable to parse
    CMP #15:BEQ ParsedOK
    INY ; skip the "." (or whatever) between the date and time
.ParseTime
    JSR ParseAndValidateTime:BCS Done ; branch if unable to parse
.ParsedOK
    ; We set the time and date separately so in principle there's a risk the user asks to set
    ; the time to "Sat,05 Nov 2022.23:59:59", we set the time first and then the clock rolls
    ; over at midnight and the date advances, then we overwrite the date with the
    ; user-specified value, so we end up at "Sat,05 Nov 2022.00:00:10" a few seconds later.
    ; tests/osword0f-d.bas explicitly tests for this and it doesn't seem to happen in practice;
    ; setting the time probably resets the sub-second count inside the RTC and we always get
    ; the date set before the time can roll over at midnight.
    JSR CopyPrvTimeToRtc
    JSR CopyPrvDateToRtc
.Done
    PRVDIS
    JMP RestoreTransientZPAndExitAndClaimServiceCall
}
ENDIF

; Unrecognised OSWORD call - Service call &08
.service08
{
    LDA oswdbtA
IF IBOS_VERSION >= 126
    CMP #&0F:BEQ osword0f
ENDIF
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
    ; No point preserving Y? ExitServiceCall restores it anyway.
 IF IBOS_VERSION < 127
    TYA:PHA:LDY #0:LDA (oswdbtX),Y:TAX:PLA:TAY:TXA ; LDA (oswdbtX) preserving Y
 ELSE
    LDY #0:LDA (oswdbtX),Y
 ENDIF
    CMP #&60:BCC service08d
    CMP #&70:BCS service08d
    JMP osword49
.service08d
    JMP ExitServiceCall
}

; *BOOT Command
.boot
{
    PRVEN
    LDA (transientCmdPtr),Y:CMP #'?':BEQ ShowBoot
    LDA transientCmdPtr:STA osCmdPtr:LDA transientCmdPtr + 1:STA osCmdPtr + 1
    SEC:JSR GSINIT
    SEC:BEQ NoBootCommand ; branch with C set if *BOOT argument is empty and unquoted
    LDX #1
.CopyLoop
    JSR GSREAD:BCS BootCommandLengthInX ; branch if end of string
    STA prvBootCommand - 1,X
    INX:CPX #prvBootCommandMaxLength:BNE CopyLoop
    CLC
.NoBootCommand
    LDX #0
.BootCommandLengthInX
    STX prvBootCommandLength
    PRVDIS
    BCC GenerateTooLongError
    JMP ExitAndClaimServiceCall
			
.GenerateTooLongError
    JSR RaiseError
    EQUB &FD
    EQUS "Too long", &00

.ShowBoot
    LDX prvBootCommandLength:BEQ FinishShow
    LDX #1
.ShowLoop
    LDA prvBootCommand - 1,X
IF IBOS_VERSION < 127
    JSR PrintEscapedCharacter
ELSE
    BPL NotTopBitSet
    PHA
    LDA #'|':JSR OSWRCH
    LDA #'!':JSR OSWRCH
    PLA
.NotTopBitSet
    AND #&7F
    CMP #&20:BCS NotLowControl
.HighControl
    AND #&3F
.Special
    PHA
    LDA #'|':JSR OSWRCH
    PLA
    CMP #&20:BCS Printable
    ORA #'@'
.NotLowControl
    CMP #vduDel:BEQ HighControl
    CMP #'"':BEQ Special
    CMP #'|':BEQ Special
.Printable
    JSR OSWRCH
ENDIF
    INX:CPX prvBootCommandLength:BNE ShowLoop
.FinishShow
    JMP OSNEWLPrvDisExitAndClaimServiceCall

IF IBOS_VERSION < 127
.PrintEscapedCharacter
    CMP #&80:BCC NotTopBitSet
    PHA
    LDA #'|':JSR OSWRCH
    LDA #'!':JSR OSWRCH
    PLA
.NotTopBitSet
    AND #&7F
    CMP #&20:BCS NotLowControl
.HighControl
    AND #&3F
.Special
    PHA
    LDA #'|':JSR OSWRCH
    PLA
    CMP #&20:BCS Printable
    ORA #'@'
.NotLowControl
    CMP #vduDel:BEQ HighControl
    CMP #'"':BEQ Special
    CMP #'|':BEQ Special
.Printable
    JMP OSWRCH
ENDIF
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
IF IBOS_VERSION >= 127
.^prvPrintBufferBankListInitialised2
ENDIF
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
    JSR ParseBankNumber:STY TmpTransientCmdPtrOffset
    BCS prvPrintBufferBankListInitialised2 ; stop parsing if bank number is invalid
    TAY
    JSR TestForEmptySwrInBankY:TYA:BCS NotEmptySwrBank
    ; SQUASH: INC TmpBankCount:LDX TmpBankCount:STA prvPrintBufferBankList-1,X:...:CPX
    ; #MaxPrintBufferSwrBanks+1? Or initialise TmpBankCount to &FF?
    LDX TmpBankCount:STA prvPrintBufferBankList,X:INX:STX TmpBankCount
    CPX #MaxPrintBufferSwrBanks:BEQ prvPrintBufferBankListInitialised2
.NotEmptySwrBank
    LDY TmpTransientCmdPtrOffset
    JMP ParseUserBankListLoop

IF IBOS_VERSION < 127
.prvPrintBufferBankListInitialised2
    JSR InitialiseBuffer
    JMP ShowBufferSizeAndLocation
ENDIF
}

; SQUASH: Could we use this in some other places where we're initialising
; prvPrintBufferBankList? Even if we called this first and then overwrote the first entry it
; would potentially still save code.
.UnassignPrintBufferBanks
    LDA #&FF
IF IBOS_VERSION < 127
    STA prvPrintBufferBankList
    STA prvPrintBufferBankList + 1
    STA prvPrintBufferBankList + 2
    STA prvPrintBufferBankList + 3
ELSE
    LDX #3
.Loop
    STA prvPrintBufferBankList,X
    DEX:BPL Loop
ENDIF
    RTS

IF IBOS_VERSION >= 127
.^SetPrintBufferBanksToPrivateRam
    JSR UnassignPrintBufferBanks
    LDA romselCopy:AND #maxBank:ORA #romselPrvEn:STA prvPrintBufferBankList
    RTS
ENDIF

{
.UsePrivateRam
IF IBOS_VERSION < 127
    LDA romselCopy:AND #maxBank:ORA #romselPrvEn:STA prvPrintBufferBankList
    LDA #&FF
    STA prvPrintBufferBankList + 1
    STA prvPrintBufferBankList + 2
    STA prvPrintBufferBankList + 3
ELSE
    JSR SetPrintBufferBanksToPrivateRam
ENDIF
.^InitialiseBuffer
    LDA prvPrintBufferBankList:CMP #&FF:BEQ UsePrivateRam
    AND #&F0:CMP #romselPrvEn:BNE BufferInSwr1 ; SFTODO: magic
    ; Buffer is in private RAM, not sideways RAM.
    JSR SanitisePrvPrintBufferStart:STA prvPrintBufferBankStart
    LDA #&B0:STA prvPrintBufferBankEnd ; SFTODO: mildly magic
    LDA #0
    STA prvPrintBufferFirstBankIndex
IF IBOS_VERSION < 127
    STA prvPrintBufferBankCount
ENDIF
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
IF IBOS_VERSION < 127
    LDA prvPrintBufferSizeHigh:ADC #0:STA prvPrintBufferSizeHigh
ELSE
    INCCS prvPrintBufferSizeHigh
ENDIF
    INX:CPX #MaxPrintBufferSwrBanks:BNE CountBankLoop
    DEX
.AllBanksCounted
    LDA #&80:STA prvPrintBufferBankStart ; SFTODO: mildly magic
    LDA #0:STA prvPrintBufferFirstBankIndex
    LDA #&C0:STA prvPrintBufferBankEnd ; SFTODO: mildly magic
IF IBOS_VERSION < 127
    STX prvPrintBufferBankCount
ENDIF
    JMP PurgePrintBuffer
}
			
.ShowBufferSizeAndLocation
{
    ; Divide high and mid bytes of prvPrintBufferSize by 4 to get kilobytes.
    LDA prvPrintBufferSizeHigh:LSR A
    LDA prvPrintBufferSizeMid:ROR A:ROR A
IF IBOS_VERSION < 127
    SEC:JSR PrintADecimal
ELSE
    JSR PrintADecimalNoPad
ENDIF
    LDA prvPrintBufferBankList:AND #&F0:CMP #&40:BNE BufferInSwr2 ; SFTODO: magic constants
    LDX #0:JSR PrintKInPrivateOrSidewaysRAM ; write 'k in Private RAM'
    JMP OSNEWLPrvDisExitAndClaimServiceCall
			
.BufferInSwr2
    LDX #1:JSR PrintKInPrivateOrSidewaysRAM ; write 'k in Sideways RAM '
    LDY #0
.ShowBankLoop
    LDA prvPrintBufferBankList,Y:BMI AllBanksShown
IF IBOS_VERSION < 127
    SEC:JSR PrintADecimal
ELSE
    JSR PrintADecimalNoPad
ENDIF
IF IBOS_VERSION < 126
    LDA #',':JSR OSWRCH
ELSE
    JSR CommaOSWRCH
ENDIF
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
IF IBOS_VERSION < 127
{
    TXA:PHA
    LDA RomTypeTable,Y:BNE NotEmpty
    LDA prvRomTypeTableCopy,Y:BNE NotEmpty
    PHP:SEI
    ; Flip the bits of TestAddress in bank Y and see if the change persists, i.e. if there's
    ; RAM in that bank.
    LDA #lo(TestAddress):STA RomAccessSubroutineVariableInsn + 1
    LDA #hi(TestAddress):STA RomAccessSubroutineVariableInsn + 2
    LDA #opcodeLdaAbs:STA RomAccessSubroutineVariableInsn:JSR RomAccessSubroutine:EOR #&FF
    ; SQUASH: We keep stashing A temporarily in X here, but couldn't we just use X to do the
    ; modifications so A is naturally preserved?
    TAX:LDA #opcodeStaAbs:STA RomAccessSubroutineVariableInsn:TXA:JSR RomAccessSubroutine
    TAX:LDA #opcodeCmpAbs:STA RomAccessSubroutineVariableInsn:TXA:JSR RomAccessSubroutine
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
    TAX:LDA #opcodeStaAbs:STA RomAccessSubroutineVariableInsn:TXA:JSR RomAccessSubroutine
    PLP
    JMP PlaTaxRts
.NotEmpty
    SEC
.PlaTaxRts
    PLA:TAX
    RTS
}
ELSE
{
    TXA:PHA
    TYA:PHA
    LDA RomTypeTable,Y:BNE SecPullRts ; branch if not empty
    LDA prvRomTypeTableCopy,Y:BNE SecPullRts ; branch if not empty
    TYA:TAX:JSR TestBankXForRamUsingVariableMainRamSubroutine:BNE SecPullRts ; branch if not RAM
    CLC
    EQUB opcodeLdaImmediate ; skip following SEC
.SecPullRts
    SEC
    PLA:TAY
    PLA:TAX
    RTS
}
ENDIF
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
IF IBOS_VERSION < 127
    SEC:JSR PrintADecimal
ELSE
    JSR PrintADecimalNoPad
ENDIF
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
IF IBOS_VERSION < 127
    ; SFTODO: We seem to be using currentLanguageRom if b7 clear, otherwise we take the bank number from romsel (which will be our bank, won't it) - not sure what's going on exactly
    LDA currentLanguageRom:BPL L8FBF
    LDA romselCopy:AND #maxBank
.L8FBF
    PHA:JSR DisableTube:PLA
    TAX:JMP DoOsbyteEnterLanguage
ELSE
    JSR DisableTube
    ; We would like to re-enter the current language to make things as transparent as possible,
	; but that will fail if the current language is a HI language. If that's the case, we enter
	; the *CONFIGUREd language instead, which may in turn decide to fall back to the IBOS NLE.
    LDX currentLanguageRom:JSR EnterLangXIfNonHi
    JMP EnterConfiguredLanguage
ENDIF

.^DisableTube
    LDA #0:LDX #prvDesiredTubeState - prv83:JSR WritePrivateRam8300X
    LDA #&FF:LDX #prvTubeOnOffInProgress - prv83:JSR WritePrivateRam8300X
    LDA #0:STA tubePresenceFlag
    ; Re-select the current filing system.
    LDA #osargsReadFilingSystemNumber:LDX #TransientZP:LDY #0:JSR OSARGS ; SQUASH: don't set X?
    TAY:LDX #serviceSelectFilingSystem:JSR DoOsbyteIssueServiceRequest
    LDA #0:LDX #prvTubeOnOffInProgress - prv83:JMP WritePrivateRam8300X

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
    LDA #&FF:LDX #prvDesiredTubeState - prv83:JSR WritePrivateRam8300X
    LDX #prvTubeOnOffInProgress - prv83:JSR WritePrivateRam8300X
    LDX #&FF:LDY #0:JSR DoOsbyteIssueServiceRequest
    LDA #&FF:STA tubePresenceFlag
    LDX #serviceTubePostInitialisation:LDY #0:JSR DoOsbyteIssueServiceRequest
    LDA #osargsReadFilingSystemNumber:LDX #&A8:LDY #&00:JSR OSARGS:TAY ; SQUASH: Don't LDX?
    LDX #serviceSelectFilingSystem:JSR DoOsbyteIssueServiceRequest
    LDA #0:LDX #prvTubeOnOffInProgress - prv83:JSR WritePrivateRam8300X
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
    ; SFTODO: Should we be doing AND_NOT ramselPrvs1 in the next line? Or maybe AND_NOT (ramselShen OR ramselPrvs1)?
    LDA ramselCopy:ORA #ramselPrvs1:STA ramselCopy:STA ramsel
    LDA romselCopy:ORA #romselPrvEn:STA romselCopy:STA romsel
    PLA
    RTS
			
; Page out private RAM. Preserves A, X, Y and carry.
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
IF INCLUDE_APPEND
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
ELSE
    ; Stub *APPEND implementation for INCLUDE_APPEND=FALSE case.
    JMP OSNEWLPrvDisExitAndClaimServiceCall
.printSpace
    LDA #' ':JMP OSWRCH
ENDIF

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
    JSR FindNextCharAfterSpace
IF IBOS_VERSION < 127
    LDA (transientCmdPtr),Y ; Redundant. Included in JSR FindNextCharAfterSpace
ENDIF
    CMP #vduCr:BNE HaveFilename
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
.ConfParBit
IF IBOS_VERSION < 126
		EQUB userRegLangFile,&00,&04						;FILE ->	  &05 Bits 0..3
		EQUB userRegLangFile,&04,&04						;LANG ->	  &05 Bits 4..7
ELSE
		EQUB userRegFile,&00,&04						;FILE ->	  &11 Bits 0..3
		EQUB userRegLang,&00,&08						;LANG ->	  &05 Bits 4..7 tube language, bits 0..3 non-tube language
ENDIF
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
IF IBOS_VERSION < 126
		EQUW Conf1-1							;LANG <0-15>		Type 1: Number starting 0
ELSE
		EQUW ConfLang-1							;LANG <0-15>(,<0-15)	Language: pair of ROM bank numbers
ENDIF
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
IF IBOS_VERSION >= 126
    EQUB %11111111 ; TODO: may be better to rewrite to avoid needing this, but let's do this for now
ENDIF


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
IF IBOS_VERSION < 126
    JSR ibosRef
ENDIF
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
    JSR FindNextCharAfterSpace
IF IBOS_VERSION < 127
    LDA (transientCmdPtr),Y ; Redundant. Included in JSR FindNextCharAfterSpace
ENDIF
    AND #CapitaliseMask
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

IF IBOS_VERSION >= 126
.ConfLang
{
    IF IBOS_VERSION < 127
        Tmp = TransientZP + 7 ; ConfRefDynamicSyntaxGenerationForTransientCmdIdx uses +6
    ELSE
        ; TransientZP + {4,5,6,7} are used by PrintADecimalNoPad
        Tmp = TransientZP + 3
    ENDIF

    BCC ConfLangRead
    JSR ConvertIntegerDefaultDecimalChecked:AND #maxBank:STA Tmp:PHA
    JSR FindNextCharAfterSpaceSkippingComma:BCS NoSecondArgument
    PLA ; discard duplicate of first argument
    JSR ConvertIntegerDefaultDecimalChecked:PHA ; no need for AND #maxBank as we are going to ASL A*4
.NoSecondArgument
    PLA:ASL A:ASL A:ASL A:ASL A:ORA Tmp:JMP SetConfigValueA

.ConfLangRead
    JSR GetConfigValue:PHA
    JSR LsrA4:STA Tmp
    JSR ConfRefDynamicSyntaxGenerationForTransientCmdIdx
    PLA:AND #%00001111:JSR PrintADecimalNoPad
    CMP Tmp:BEQ OSNEWLIndirect ; just print one bank if both the same
    JSR CommaOSWRCH
    LDA Tmp:FALLTHROUGH_TO PrintADecimalNoPadNewline
}
ENDIF

.PrintADecimalNoPadNewline
    JSR PrintADecimalNoPad
.OSNEWLIndirect
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
IF IBOS_VERSION < 126
    LDA #',':JSR OSWRCH
ELSE
    JSR CommaOSWRCH
ENDIF
    PLA:AND #1:JMP PrintADecimalNoPadNewline

.ConfTVWrite
    ; SQUASH: Can't we STA Tmp instead of PHA, then omit the Lda Tmp:PLA?
    JSR ConvertIntegerDefaultDecimalChecked:AND #7:ASL A:PHA
    JSR FindNextCharAfterSpaceSkippingComma:JSR ConvertIntegerDefaultDecimalChecked:AND #1:STA Tmp
    PLA:ORA Tmp:JMP SetConfigValueA
}

IF IBOS_VERSION < 126
; Dead code
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
ELSE
.CommaOSWRCH
    LDA #',':JMP OSWRCH
ENDIF
			
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

IF IBOS_VERSION >= 124
    ; This code is to set *FX5 based off the values stored in Private RAM.
     LDX #prvSetPrinterTypePending - prv83:JSR ReadPrivateRam8300X:BEQ LeavePrinterTypeAlone
     LDA #prvOff:JSR WritePrivateRam8300X
     LDX #userRegTubeBaudPrinter:JSR ReadUserReg
     JSR LsrA5:TAX:LDA #osbyteSetPrinterType:JSR OSBYTE
.LeavePrinterTypeAlone
ENDIF

    ; SFTODO: Why set SQWE here? Is this meaningful? Is there some hardware mechanism which
    ; will force SQWE *off* on reset which thus allows it to be abused here as a "has service
    ; call 3 been issued yet?" flag???? See service10 for a check of SQWE...
    CLC:JSR AlarmAndSQWEControl ; set SQWE and AIE
    ; If we're in the middle of a full reset, the contents of RTC registers/private RAM might
    ; be gibberish so don't carry out any logic depending on them.
    BIT FullResetFlag:BPL NotFullReset ; SQUASH: BMI and get rid of following JMP
    JMP IgnorePrivateRam
.NotFullReset

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
IF IBOS_VERSION < 127
    LDA #osbyteKeyboardScanFrom10:JSR OSBYTE
ELSE
    JSR DoOsbyteKeyboardScanFrom10
ENDIF
    CPX #keycodeNone:BEQ NoKeyPressed
.IgnorePrivateRam
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
{
configuredLangTmp = TransientZP

IF IBOS_VERSION < 126
    LDX #userRegLangFile:JSR ReadUserReg:AND #maxBank:TAX ; get *CONFIGURE FILE value
ELSE
    ; Get the *CONFIGURE FILE value. SQUASH: For now it has a whole byte to itself so we could
    ; almost get away without AND #maxBank, *but* doing that would mean it has to be set to a
    ; value of the form &0x in FullReset, which would take extra code.
    LDX #userRegFile:JSR ReadUserReg:AND #maxBank:TAX
ENDIF
    ; SFTODO: If the selected filing system is >= our bank, start one bank lower?! This seems odd, although *if* we know we're bank 15, this really just means "start below us" (presumably to avoid infinite recursion)
    CPX romselCopy:BCC SelectFirstFilingSystemROMLessEqualXAndLanguage
    DEX
.^SelectFirstFilingSystemROMLessEqualXAndLanguage
    JSR PassServiceCallToROMsLessEqualX
    LDA lastBreakType:BNE EnterConfiguredLanguage
IF IBOS_VERSION < 126
    LDA currentLanguageRom:BPL EnterLangA ; SFTODO: Do we expect this to always branch? Not at all sure.
ELSE
    LDX currentLanguageRom:BPL EnterLangX ; SFTODO: Do we expect this to always branch? Not at all sure.
ENDIF
.*EnterConfiguredLanguage
IF IBOS_VERSION < 126
    LDX #userRegLangFile:JSR ReadUserReg:JSR LsrA4 ; get *CONFIGURE LANG value
    JMP EnterLangA

.NoLanguageEntryAndNoTube
    LDA romselCopy ; enter IBOS as the current language
.EnterLangA
    TAX
.EnterLangX
    LDA RomTypeTable,X:ROL A:BPL NoLanguageEntry
    JMP osEntryClcOsbyteEnterLanguage

.NoLanguageEntry
    ; I don't think this case adds any value compared to just entering IBOS as the current
    ; language. The tube probably isn't going to do anything exciting when told no language was
    ; found at break, and I don't think it can be important to trigger this case because on a
    ; BBC B without IBOS 99.9% of the time there *will* be a language (6502 BBC BASIC) whatever
    ; co-pro is connected.
    BIT tubePresenceFlag:BPL NoLanguageEntryAndNoTube
    ; Inform tube no language was found at break.
    LDA #0:CLC:JMP L0400
ELSE
    LDX #userRegLang:JSR ReadUserReg
    ; A is now &tn where t is the language bank if tube is present, n if tube is not present.
    BIT tubePresenceFlag:BMI EnterLangALsr4 ; branch if tube is present to enter bank &t
    ; Tube is not present, so we want to enter bank &n. However, if that bank has a relocation
    ; address other than &8000, we can't enter it without hanging, so we check that first. If
    ; we can't enter it safely, we'll fall back to the IBOS NLE.
    AND #maxBank
    TAX
IF IBOS_VERSION < 127
    LDA RomTypeTable,X:AND #%00100000:BEQ EnterLangX ; branch if relocation bit not set
    JSR SetOsRdRmPtrToCopyrightOffset
    STX configuredLangTmp
    JSR OsRdRmFromConfiguredLangTmp:STA osRdRmPtr ; set osRdRmPtr to copyright string
.FindRelocationAddressLoop
    JSR OsRdRmFromConfiguredLangTmpWithPreInc
    ; On OS 1.20 we know the flags after calling OSRDRM reflect the value in A.
    BNE FindRelocationAddressLoop
    ; osRdRmPtr now points to the NUL at the end of the copyright string. Advance it by two so
    ; we can check the high byte of the relocation address. Ideally we'd check the low byte of
    ; the relocation address is 0, but I don't think it's critical and it saves code to just
    ; check the high byte.
    INC osRdRmPtr ; assume we never wrap past the first page of the ROM
    JSR OsRdRmFromConfiguredLangTmpWithPreInc
    LDX configuredLangTmp
    CMP #&80:BEQ EnterLangX ; branch if this language has a relocation address &80xx
    BNE NoLanguageEntry ; always branch
ELSE
    JSR EnterLangXIfNonHi
    JMP NoLanguageEntry
ENDIF
.EnterLangALsr4
    JSR LsrA4
    TAX
.EnterLangX
    ; Before trying to enter bank X as a language, we check it has a language entry. If it
    ; doesn't, we'll fall back to the IBOS NLE.
    LDA RomTypeTable,X:ROL A:BMI HasLanguageEntry
.NoLanguageEntry
    LDX romselCopy ; enter IBOS as the current language; we know it has a language entry!
.HasLanguageEntry
    JMP osEntryClcOsbyteEnterLanguage

.OsRdRmFromConfiguredLangTmpWithPreInc
    INC osRdRmPtr ; assume we never wrap past the first page of the ROM
.OsRdRmFromConfiguredLangTmp
    LDY configuredLangTmp:JMP OSRDRM
ENDIF

IF IBOS_VERSION >= 127
; Enters the language in bank X if it's not a HI language, otherwise returns with X preserved.
; If X is not a language at all, this will enter the IBOS NLE.
.*EnterLangXIfNonHi
    LDA RomTypeTable,X:AND #%00100000:BEQ EnterLangX ; branch if relocation bit not set
    JSR SetOsRdRmPtrToCopyrightOffset
    STX configuredLangTmp
    JSR OsRdRmFromConfiguredLangTmp:STA osRdRmPtr ; set osRdRmPtr to copyright string
.FindRelocationAddressLoop
    JSR OsRdRmFromConfiguredLangTmpWithPreInc
    ; On OS 1.20 we know the flags after calling OSRDRM reflect the value in A.
    BNE FindRelocationAddressLoop
    ; osRdRmPtr now points to the NUL at the end of the copyright string. Advance it by two so
    ; we can check the high byte of the relocation address. Ideally we'd check the low byte of
    ; the relocation address is 0, but I don't think it's critical and it saves code to just
    ; check the high byte.
    INC osRdRmPtr ; assume we never wrap past the first page of the ROM
    JSR OsRdRmFromConfiguredLangTmpWithPreInc
    LDX configuredLangTmp
    CMP #&80:BEQ EnterLangX ; branch if this language has a relocation address &80xx
    RTS
ENDIF
}

; SFTODO: This has only one caller
.PassServiceCallToROMsLessEqualX
    TXA:PHA
IF IBOS_VERSION < 126
    TSX:LDA L0104,X:TAY ; get Y from the service call
ELSE
    TSX:LDY L0104,X ; get Y from the service call
ENDIF
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

IF IBOS_VERSION >= 122
    ; ANFS 4.18 issues service call 1 a second time during reset. This causes various problems,
    ; most noticeably a lock up where IbosSetup can claim the vectors a second time and the
    ; parent vector handlers point back into IBOS, causing an infinite loop when we try to
    ; chain to the parent. We check right away to see if we've already claimed the vectors
    ; (just checking BYTEV is enough) and ignore this service call if we have.
    LDA BYTEVL:CMP #lo(osPrintBuf):BNE VectorsNotAlreadyClaimed
    LDA BYTEVH:CMP #hi(osPrintBuf):BEQ VectorsAlreadyClaimed
.VectorsNotAlreadyClaimed
ENDIF
    ; SFTODO: What are prv83+[1-7] here? We are setting them to &FF.
    ; SQUASH: I think this code is high enough in the IBOS ROM we don't need to be indirecting
    ; via WritePrivateRam8300X and could just set PRV1 and access directly?
    LDA #0:STA ramselCopy:STA ramsel ; shadow off SFTODO?
    LDX #7
    LDA #&FF
.WriteLoop
    JSR WritePrivateRam8300X
    DEX:BNE WriteLoop
    LDA romselCopy:AND #maxBank:ASSERT prvIbosBankNumber == prv83 + 0:JSR WritePrivateRam8300X
    ; If we're in the middle of a full reset, the contents of RTC registers/private RAM might
    ; be gibberish so don't carry out any logic depending on them.
    BIT FullResetFlag:BPL NotFullReset ; SQUASH: BMI and get rid of following JMP?
.VectorsAlreadyClaimed
    JMP ExitServiceCallIndirect
.NotFullReset
    LDX #userRegPrvPrintBufferStart:JSR ReadUserReg
    LDX #prvPrvPrintBufferStart-prv83:JSR WritePrivateRam8300X
    LDX lastBreakType:BEQ SoftReset

IF IBOS_VERSION >= 124
    ASSERT prvSetPrinterTypePending - prv83 <> 0
    LDX #prvSetPrinterTypePending - prv83:TXA:JSR WritePrivateRam8300X
ENDIF

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

    LDX #userRegTubeBaudPrinter:JSR ReadUserReg
IF IBOS_VERSION < 127
    JSR LsrA2
ELSE
    LSR A:LSR A
ENDIF
    PHA
    AND #&07:CLC:ADC #1 ; mask off baud rate bits and add 1 to convert to 1-8 range
    PHA:TAX:LDA #osbyteSetSerialReceiveRate:JSR OSBYTE
    PLA:TAX:LDA #osbyteSetSerialTransmitRate:JSR OSBYTE
    PLA
    
IF IBOS_VERSION < 124
    JSR LsrA3:TAX:LDA #osbyteSetPrinterType:JSR OSBYTE
ENDIF

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

IF IBOS_VERSION >= 124
.LsrA5
    LSR A
ENDIF

.LsrA4
    LSR A
; SQUASH: Use of JSR LsrA3 or JSR LsrA2 is silly - the former is neutral on space and slower,
; the latter is both larger and slower.
.LsrA3
    LSR A
IF IBOS_VERSION < 127
.LsrA2
ENDIF
    LSR A
    LSR A
    RTS

; Tube system initialisation - service call &FF
; SFTODO: Not at all clear what's going on here
.serviceFF
{
    XASSERT_USE_PRV1
IF IBOS_VERSION < 127
    JSR clearShenPrvEn
    PHA
ELSE
    LDA ramselCopy:PHA
    LDA #0:STA ramselCopy:STA ramsel
    PRVEN
ENDIF
    BIT prvTubeOnOffInProgress:BMI L9836
    LDA lastBreakType:BEQ SoftReset
    ; If we're in the middle of a full reset, the contents of RTC registers/private RAM might
    ; be gibberish so don't carry out any logic depending on them.
    BIT FullResetFlag:BMI FullReset
    LDX #userRegTubeBaudPrinter:JSR ReadUserReg:AND #1:BNE WantTube ; branch if *CONFIGURE TUBE
    LDA #&FF
.WantTube
    STA prvDesiredTubeState ; note A is 1 or &FF here, so we must always test b7 not 0/non-0
.SoftReset
    BIT prvDesiredTubeState:BPL L983D
.L9836
    PLA:JSR PRVDISStaRamsel
    JMP ExitServiceCall
.L983D
.FullReset
    PLA:JSR PRVDISStaRamsel
    PLA:TAY ; restore original Y on entry to service call
    PLA ; discard stacked original X
    PLA ; discard stacked original A
    LDA #&FF
    LDX #&00
    JMP osStxRomselAndCopyAndRts

; SQUASH: This only has one caller
IF IBOS_VERSION < 127
.clearShenPrvEn ; SFTODO: not super happy with this name
    LDA ramselCopy:PHA
    LDA #0:STA ramselCopy:STA ramsel
    PRVEN
    PLA
    RTS
ENDIF

.PRVDISStaRamsel
    PHA
    PRVDIS
    PLA
    STA ramselCopy
    STA ramsel
IF IBOS_VERSION > 126
.^altRTS
ENDIF
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
.DisplayBannerIfRequired
{
IF IBOS_VERSION < 127
RamPresenceFlags = TransientZP
ENDIF

    ; We just use the default banner if we're in OSMODE 0.
    LDX #prvOsMode - prv83:JSR ReadPrivateRam8300X
IF IBOS_VERSION < 127    
    CMP #0 ; redundant
    BEQ Rts
ELSE
    BEQ altRTS ; Rts is too far away.
ENDIF
    ; If we're in the "ignore OS startup message" state (b7 clear), do nothing. I suspect this
    ; occurs if an earlier ROM has managed to get in before us and probably can't occur in
    ; practice if we're in bank 15.
    LDA #osbyteReadWriteEnableDisableStartupMessage:LDX #0:LDY #&FF:JSR OSBYTE:TXA:BPL Rts

    ; Set the "ignore OS startup message" state ourselves. We will also clear bit 0
    ; unconditionally rather than preserving it, but in practice this probably doesn't matter
    ; (it controls locking up the machine on certain types of !BOOT error).
    LDA #osbyteReadWriteEnableDisableStartupMessage:LDX #0:LDY #0:JSR OSBYTE

IF IBOS_VERSION < 126
    ; Print "Computech".
    LDX #ComputechStart - RomHeader
.BannerLoop1
    LDA RomHeader,X:JSR OSWRCH
    INX:CPX #(ComputechEnd + 1) - RomHeader:BNE BannerLoop1
ENDIF

    ; Print " INTEGRA-B".
    LDX #(ReverseBannerEnd - 1) - ReverseBanner
.BannerLoop2
    LDA ReverseBanner,X:JSR OSWRCH
    DEX:BPL BannerLoop2

    LDA lastBreakType:BEQ SoftReset ; soft reset message is simpler and quieter

    LDA #vduBell:JSR OSWRCH

 
IF IBOS_VERSION < 127
 ; Count 32K chunks of RAM in kilobytes and print the result.
    LDX #userRegRamPresenceFlags:JSR ReadUserReg:STA RamPresenceFlags
    LDX #7
    LDA #0
.CountLoop
    LSR RamPresenceFlags:BCC NotPresent ; branch if no RAM in this bank
    ADC #32 - 1 ; add 32K, -1 because carry is set
.NotPresent
    DEX:BPL CountLoop
    ; If we have 256K of RAM A will have wrapped to 0; we can't have 0K of RAM so there's no
    ; ambiguity.
    CMP #0:BEQ AllBanksPresent ; SQUASH: use TAX instead of CMP #0
    SEC:JSR PrintADecimal
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
ELSE
; Count 16K chunks of RAM in kilobytes and print the result.
    LDY #4 ; number of 16K RAM chunks - initial 4 are 32K main RAM, 20K shadow and 12K private
; Firstly, test for V2 hardware...
    JSR testV2hardware
    BCC endppaddram
; Check for PALPROM banks, and increment Y by the number of extra banks in use
    LDX #3
.palpromaddramloop
; Check if PALPROM banks 8..11 are configured as RAM or ROM
; SQUASH: Any prospect of shifting a temp copy of this value each time round the look instead of anding it with a table?
    LDA cpldRAMROMSelectionFlags8_F
    AND RegRamMaskTable,X:BEQ notpalprom
; If configured as RAM, check if PALPROM is enabled
    LDA cpldPALPROMSelectionFlags0_7 ; PALPROM Flags
    AND palprom_test_table,X:BEQ notpalprom
    LDA palprom_banks_table,X ; number of extra PALPROM RAM banks
    JSR sumRAMLoop
.notpalprom
    DEX
    BPL palpromaddramloop
.endppaddram
    LDX #userRegRamPresenceFlags0_7:JSR sumRAM
    ASSERT userRegRamPresenceFlags0_7 + 1 == userRegRamPresenceFlags8_F
    INX:JSR sumRAM
    STA transientBin+1 ; we know A is zero after sumRAM
    ; Y <= 32 here - we started at 4 and can have added a maximum of 16 sideways RAM banks and 12 extra PALPROM banks
    TYA
    ASL A ; result <= 64, no carry
    ASL A ; result <= 128, no carry
    ASL A:ROL transientBin+1 ; result <= 256, so may have carry
    ASL A:STA transientBin:ROL transientBin+1 ; <= 512, so may have carry
    SEC
    JSR PrintAbcd16Decimal
    LDA #'K':JSR OSWRCH
.SoftReset
    JSR OSNEWL
    BIT tubePresenceFlag:BMI Rts ; branch if tube present
    JMP OSNEWL

; Increment Y by the number of bits set in user register A. Preserves X, returns with A=0.
.sumRAM
    JSR ReadUserReg ; preserves X and Y
.sumRAMLoop
    LSR A
    PHP
    BCC sumRAMNoAdd
    INY
.sumRAMNoAdd
    PLP
    BNE sumRAMLoop
.Rts
    RTS
ENDIF



.ReverseBanner
    EQUS " B-ARGETNI" ; "INTEGRA-B " reversed
IF IBOS_VERSION >= 126
    EQUS " orciM CBB" ; "BBC Micro " reversed
ENDIF
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
    TAX:JSR TestBankXForRamUsingVariableMainRamSubroutine:BNE NotRam
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
	  ; SFTODO: Is all the saving and restoring of Y needed? FindAInPrvSrDataBanks doesn't seem to corrupt Y.
            LDY #&03
.bankLoop   STY prvTmp
            LDA prvPseudoBankNumbers,Y
            BMI bankAbs   								;&FF indicates no absolute bank assigned to this pseudo-bank SFTODO: I guess we say that's an absolute addressing bank as it is less likely our caller will decide to try to use it, but it is a bit arbitrary
            JSR FindAInPrvSrDataBanks ; SFTODO: I am inferring SrDataBanks is therefore a list of up to 4 banks being used for pseudo-addressing - the fact we need to do the previous BMI suggests the list is padded to the full 4 entries with &FF
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
    JSR ParseRomBankListChecked2
    PRVEN
    LDX #0
.BankLoop
    ROR transientRomBankMask + 1:ROR transientRomBankMask:BCC SkipBank
    JSR WipeBankXIfRam
.SkipBank
    INX:CPX #maxBank + 1:BNE BankLoop
    JMP PrvDisexitSc

; SQUASH: This has only one caller, the code immediately above - could it just be inlined?
.WipeBankXIfRam
IF IBOS_VERSION < 127
    JSR TestBankXForRamUsingVariableMainRamSubroutine:BNE Rts
    PHA
ENDIF
IF IBOS_VERSION >= 127
    TXA:PHA:CLC:JSR ensureBankAIsUsableRamIfPossible
ENDIF
    LDX #lo(wipeBankATemplate):LDY #hi(wipeBankATemplate):JSR CopyYxToVariableMainRamSubroutine
    PLA
    JSR variableMainRamSubroutine
IF IBOS_VERSION < 127
; In IBOS Version >= 127, this function is carried out in ensureBankAIsUsableRamIfPossible
    PHA:JSR removeBankAFromSrDataBanks:PLA ; SFTODO: So *SRWIPE implicitly performs a *SRROM on each bank it wipes?
ENDIF
    TAX:LDA #0:STA RomTypeTable,X:STA prvRomTypeTableCopy,X
.Rts
    RTS
}

IF IBOS_VERSION < 126
; Dead data
{
    EQUS "RAM","ROM"
}
ENDIF

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
    LDA #'O':STA WriteRomHeaderDataAO
.Ram
    LDA prvOswordBlockCopy + 1 ; SFTODO: THIS IS THE SAME LOCATINO AS IN SRROM/SRDATA SO WE NEED A GLOBAL NAME FOR IT RATHER THAN JUST THE LOCAL ONE WE CURRENTLY HAVE (bankTmp)
    JSR checkRamBankAndMakeAbsolute
    STA prvOswordBlockCopy + 1
    STA WriteRomHeaderDataSFTODO
    JMP variableMainRamSubroutine
}

{
; Search prvSrDataBanks for A; if found, remove it, shuffling the elements down so all the non-&FF entries are at the start and are followed by enough &FF entries to fill the list.
.^removeBankAFromSrDataBanks
    XASSERT_USE_PRV1
    LDX #3 ; SFTODO: MILDLY MAGIC
.FindLoop
    CMP prvSrDataBanks,X:BEQ Found
    DEX:BPL FindLoop
    SEC ; SFTODO: Not sure any callers care about this, and I think we'll *always* exit with carry set even if we do find a match
    RTS

.Found
    LDA #&FF:STA prvSrDataBanks,X
.Shuffle
    LDX #0:LDY #0
.ShuffleLoop
    LDA prvSrDataBanks,X:BMI Unassigned
    STA prvSrDataBanks,Y:INY
.Unassigned
    INX:CPX #&04:BNE ShuffleLoop ; SFTODO: mildly magic
    TYA:TAX
    JMP PadLoopStart ; SQUASH: BPL always?
			
.PadLoop
    LDA #&FF:STA prvSrDataBanks,Y
    INY
.PadLoopStart
    CPY #4:BNE PadLoop  ; SFTODO: mildly magic
    RTS

; If there's an unused entry, add A to SrDataBanks and return with C clear, otherwise
; return with C set to indicate no room.
; SQUASH: This has only one caller
.^AddBankAToSrDataBanks
    XASSERT_USE_PRV1
    PHA:JSR Shuffle:PLA
    CPX #4:BCS Rts ; SFTODO: mildly magic
    STA prvSrDataBanks,X
.Rts
    RTS
}

; Return with X such that prvSrDataBanks[X] == A (N flag clear), or with X=-1 if there is no such X (N flag set).
; SQUASH: This only has one caller
.FindAInPrvSrDataBanks
{
    XASSERT_USE_PRV1
    LDX #3 ; SFTODO: mildly magic
.Loop
    CMP prvSrDataBanks,X:BEQ Rts
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
      ; SFTODONOW: Should this exclude write-protected banks? I can see arguments either way.
      ; ENHANCE: This does not check the state after ParseRomBankList - "*SRSET HG" is
      ; accepted. Care is needed here as arguably "*SRSET" is legitimate, specifying no pseudo
      ; banks are defined.
            JSR ParseRomBankList
            PRVEN
            LDX #&00
            LDY #&00
.bankLoop   ROR transientRomBankMask + 1
            ROR transientRomBankMask
            BCC SkipBank
            TYA
            PHA
            JSR TestBankXForRamUsingVariableMainRamSubroutine
            BNE plyAndSkipBank ; branch if not RAM
            LDA prvRomTypeTableCopy,X
            BEQ emptyBank
            CMP #RomTypeSrData
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
            SEC ; SQUASH: PrintADecimalNoPad?
            JSR PrintADecimal								;Convert binary number to numeric characters and write characters to screen
.bankShown  CPY #&03								;Check for 4th bank
            BEQ osnewlPrvDisexitSc							;Yes? Then end
IF IBOS_VERSION < 126
            LDA #','
            JSR OSWRCH								;Write to screen
ELSE
	  JSR CommaOSWRCH
ENDIF
            JSR printSpace								;write ' ' to screen
            INY									;Next
            BNE ShowLoop								;Loop for 'X', 'Y' & 'Z'
.osnewlPrvDisexitSc
            JSR OSNEWL								;New Line
            JMP PrvDisexitSc
}

{
;*SRROM Command
.^srrom
    SEC:BCS Common ; always branch

;*SRDATA Command
.^srdata
    CLC
.Common
    PHP
    JSR ParseRomBankListChecked2
    PRVEN
    LDX #0
.BankLoop
    ROR transientRomBankMask + 1:ROR transientRomBankMask:BCC SkipBank
    PLP:PHP:JSR DoBankX
.SkipBank
    INX:CPX #maxBank + 1:BNE BankLoop
    JMP plpPrvDisexitSc ; SQUASH: close enough to BEQ always?

    ; SQUASH: This has only one caller and a single RTS, so can it just be inlined?
    ; SQUASH: DoBankX seems to set/clear C/V to indicate things, but nothing seems to check them.
    ; SQUASH: Although some other code uses prvOswordBlockCopy + 1 to hold a bank number, I
    ; don't believe this code is ever used in conjunction with an OSWORD call. If that's right,
    ; we could shorten the code slightly by using a zero-page temporary for bankTmp.
bankTmp = prvOswordBlockCopy + 1
RomRamFlagTmp = L00AD ; &80 for *SRROM, &00 for *SRDATA
.DoBankX
    STX bankTmp
    PHP
    LDA #0:ROR A:STA RomRamFlagTmp ; put C in b7 of RomRamFlagTmp
    JSR TestBankXForRamUsingVariableMainRamSubroutine:BNE FailSFTODOA ; branch if not RAM
    LDA prvRomTypeTableCopy,X:BEQ EmptyBank
    CMP #RomTypeSrData:BNE FailSFTODOA
.EmptyBank
    LDA bankTmp:JSR removeBankAFromSrDataBanks
    PLP:BCS IsSrrom
    LDA bankTmp:JSR AddBankAToSrDataBanks:BCS FailSFTODOB ; branch if already had max banks
.IsSrrom
    LDA RomRamFlagTmp:JSR WriteRomHeaderAndPatchUsingVariableMainRamSubroutine
    LDX bankTmp:LDA #RomTypeSrData:STA prvRomTypeTableCopy,X:STA RomTypeTable,X
.RestoreXRts
	LDX bankTmp
.Rts
    RTS

    ; SQUASH: Set/clear V first in both these cases, then the first can "BVC always" to SEC:BCS
    ; RestoreXRts in second.
.FailSFTODOA
	PLP
    SEC
    CLV
    BCS RestoreXRts ; always branch
.FailSFTODOB
	SEC
    BIT Rts ; set V
    BCS RestoreXRts ; always branch
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


; At the moment this is only used by *SRWIPE, *SRROM and *SRDATA.
; SFTODO: Do we really need this *and* ParseRomBankListChecked? Isn't ParseRomBankListChecked
; better than this one?
; SFTODONOW: I think as written ...Checked *is* better and would be a drop-in replacement -
; would need to test. However, since I am looking to add write protect/*SRDATA/PALPROM check
; logic, I need to be careful. It may be ...Checked could still be used everywhere and take a
; flag to tell it what to do about checking for write protect etc.
.ParseRomBankListChecked2
{
.L9B25      JSR ParseRomBankList
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
.L9BBC     JSR checkRamBankAndMakeAbsolute					;convert pseudo RAM bank to absolute RAM bank
            STA prvOswordBlockCopy + 1						;and save to private address &8221
            RTS
}

IF IBOS_VERSION >= 127
.ensureOswordBlockBankIsUsableRamIfPossibleViaOsword
{
    SEC
    EQUB opcodeLdaImmediate ; skip following CLC
.^ensureOswordBlockBankIsUsableRamIfPossibleViaStarCmd
    CLC
    BIT prvOswordBlockCopy:BPL Rts ; branch if reading from SWR
    LDA prvOswordBlockCopy + 1:BMI Rts ; branch if pseudo addressing in operation
; Alternate entry point with the bank number in A and therefore no checks for the OSWORD block
; specifying a write or that normal non-pseudo addressing is in use. The behavior is otherwise
; identical.
.^ensureBankAIsUsableRamIfPossible
    BCS Rts
    TAX
    PHP
    JSR TestBankXForRamUsingVariableMainRamSubroutine:BNE notWERam ; branch if not RAM
    PLP
    TXA:PHA
    JSR removeBankAFromSrDataBanks
    PLA:TAX
    JSR testV2hardware:BCC Rts
    CPX #8:BCC Rts
    CPX #12:BCS Rts
    LDA palprom_test_table-8,X:EOR #&FF
    AND cpldPALPROMSelectionFlags0_7
    STA cpldPALPROMSelectionFlags0_7
    LDX #userRegPALPROMConfig:JSR WriteUserReg
.Rts
    RTS

.notWERam
    PLP
    BCS Rts
    JSR RaiseError
    EQUB &83
    EQUS "Not W/E RAM", &00
}
ENDIF

; SFTODO: Returns with C clear in "simple" case, C set in the "mystery" case (which is probably no bank number being specified so we are implicitly using pseudo addressing to save a chunk of the *SRDATA banks)
.ParseBankNumberIfPresent ; SFTODO: probably imperfect name, will do until the mystery code in middle is cleared up
{
    XASSERT_USE_PRV1
            JSR ParseBankNumber
            BCC parsedOk
            LDA #&FF ; SFTODO: What happens if we have the ROM number set to &FF later on?
.parsedOk   STA prvOswordBlockCopy + 1						;absolute ROM number
            BCC parsedOk2
	  ; SFTODO: What do these addresses hold? I *speculate* they hold the real banks assigned to pseudo-banks W-Z, &FF meaning "not assigned".
            LDA prvSrDataBanks
            AND prvSrDataBanks + 1
            AND prvSrDataBanks + 2
            AND prvSrDataBanks + 3
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
IF IBOS_VERSION < 127
            LDA (transientCmdPtr),Y ; Redundant. Included in JSR FindNextCharAfterSpace
ENDIF
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
IF IBOS_VERSION < 127
            LDA (transientCmdPtr),Y
ENDIF
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
IF IBOS_VERSION < 127
            LDA (transientCmdPtr),Y ; Redundant. Included in JSR FindNextCharAfterSpace
ENDIF
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
            JMP L9CDF ; SQUASH: BEQ always or use BIT to skip next two bytes
			
;*SRWRITE Command
.^srwrite	  PRVEN								;switch in private RAM
            LDA #&80
.L9CDF      STA prvOswordBlockCopy
            LDA #&00
            STA L02EE
            JSR L9C52
            JSR parseOsword4243Length
            JSR L9C42
	  JSR ParseBankNumberIfPresent
IF IBOS_VERSION >= 127
	  JSR ensureOswordBlockBankIsUsableRamIfPossibleViaStarCmd
ENDIF
            JMP osword42Internal
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
            LDA prvSrDataBanks,X
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
            LDA prvSrDataBanks,X
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
;On exit A=X=ROM bank that has been tested. Z contains test result (Z set iff RAM).
;this code is relocated to and executed at &03A7
.TestRamTemplate
{
    ORG variableMainRamSubroutine

    LDX romselCopy
    STA romselCopy:STA romsel
    LDA romBinaryVersion:EOR #&FF:STA romBinaryVersion
    JSR Delay:JSR Delay:JSR Delay:JSR Delay
    CMP romBinaryVersion:PHP
    EOR #&FF:STA romBinaryVersion
    LDA romselCopy
    STX romselCopy:STX romsel
    TAX
    PLP
.Delay
    RTS

    RELOCATE variableMainRamSubroutine, TestRamTemplate
    ASSERT P% - TestRamTemplate <= variableMainRamSubroutineMaxSize
}

;Wipe RAM at bank A
;this code is relocated to and executed at &03A7
.wipeBankATemplate
{
    ORG variableMainRamSubroutine

    LDX romselCopy
    STA romselCopy:STA romsel
    LDA #0
.wipeLoop
.staAbs
    STA &8000 ; SFTODO: mildly magic
    INC staAbs + 1:BNE wipeLoop
    INC staAbs + 2:BIT staAbs + 2:BVC wipeLoop ; test high byte bit 6 (have we reached &4000?)
    LDA romselCopy
    ; SQUASH: We could replace next three instructions with JMP osStxRomselAndCopyAndRts.
    STX romselCopy:STX romsel
    RTS

    RELOCATE variableMainRamSubroutine, wipeBankATemplate
    ASSERT P% - wipeBankATemplate <= variableMainRamSubroutineMaxSize
}

;write ROM header to RAM at bank A
;this code is relocated to and executed at &03A7
.WriteRomHeaderTemplate
{
    ORG variableMainRamSubroutine

    LDX romselCopy
    STA romselCopy:STA romsel
    LDY #(SrDataHeaderEnd - SrDataHeader) - 1
.CopyLoop
    LDA SrDataHeader,Y:STA &8000,Y ; SFTODO: mildly magic
    DEY:BPL CopyLoop
    LDA romselCopy
    ; SQUASH: We could replace next three instructions with JMP osStxRomselAndCopyAndRts.
    STX romselCopy:STX romsel
    RTS

;ROM Header
.SrDataHeader
    EQUB opcodeRts
.^WriteRomHeaderDataSFTODO ; SFTODO: Why do we modify this byte of the header?
    EQUB           &00,&00
    EQUB opcodeRts,&00,&00
    EQUB RomTypeSrData ; SFTODO: This constant is arguably misnamed since we use it for *SRROM banks too (I think)
    EQUB &0C
    EQUB &FF
    EQUS "R"
.^WriteRomHeaderDataAO
    EQUS "AM", &00
    EQUS "(C)"
.SrDataHeaderEnd

    RELOCATE variableMainRamSubroutine, WriteRomHeaderTemplate
    ASSERT P% - WriteRomHeaderTemplate <= variableMainRamSubroutineMaxSize
}

;save ROM / RAM at bank X to file system
;this code is relocated to and executed at &03A7
; SFTODO: Y ON ENTRY IS BYTES TO READ
.saveSwrTemplate
{
    ORG variableMainRamSubroutine

    TXA
    LDX romselCopy
    STA romselCopy:STA romsel
    ; SQUASH: We could STY this directly to immediate operand of CPY #n, saving a byte.
    INY:STY BytesToRead
    LDY #0
    ; SQUASH: It would be shorter by one byte to just STY to overwrite the operand of LDY #n after JSR OSBPUT.
.Loop
    STY SavedY
    LDA (L00A8),Y:LDY L02EE:JSR OSBPUT ; SFTODO: magic addresses
    LDY SavedY
    INY:CPY BytesToRead:BNE Loop
    LDA romselCopy
    STX romselCopy:STX romsel
    TAX
    RTS

BytesToRead = P% ; 1 byte
SavedY = P% + 1 ; 1 byte

    RELOCATE variableMainRamSubroutine, saveSwrTemplate
    ; There are two bytes of space used at BytesToRead/SavedY when this copied into RAM but
    ; they're not present in the ROM, hence P% + 2 in the next line.
    ASSERT (P% + 2) - saveSwrTemplate <= variableMainRamSubroutineMaxSize
}

;load ROM / RAM at bank X from file system
;this code is relocated to and executed at &03A7
.loadSwrTemplate
{
    ORG variableMainRamSubroutine

    TXA
    LDX romselCopy
    STA romselCopy:STA romsel
    ; SQUASH: We could STY this directly to immediate operand of CPY #n, saving a byte.
    INY:STY BytesToRead
    LDY #0
    ; SQUASH: It would be shorter by one byte to just STY to overwrite the operand of LDY #n after JSR OSBGET.
.Loop
    STY SavedY
    LDY L02EE:JSR OSBGET
    LDY SavedY
    STA (transientOs4243SwrAddr),Y ; SFTODO: I think this is used by OSWORD &43, if so rename transientOs4243SwrAddr TO INDICATE APPLIES TO BOTH (tho that's only a temp name)
    INY:CPY BytesToRead:BNE Loop
    LDA romselCopy
    STX romselCopy:STX romsel
    TAX
    RTS

BytesToRead = P% ; 1 byte
SavedY = P% + 1 ; 1 byte

    RELOCATE variableMainRamSubroutine, loadSwrTemplate
    ; There are two bytes of space used at BytesToRead/SavedY when this copied into RAM but
    ; they're not present in the ROM, hence P% + 2 in the next line.
    ASSERT (P% + 2) - loadSwrTemplate <= variableMainRamSubroutineMaxSize
}

;Function TBC
;this code is relocated to and executed at &03A7
; SFTODO: The need to separate treatment of the last byte seems awkward (especially when it
; means extra patching), can we avoid it?
.mainRamTransferTemplate
{
    ORG variableMainRamSubroutine

    TXA
    LDX romselCopy
    STA romselCopy:STA romsel
    CPY #0:BEQ LastByte ; SQUASH: CPY #0 -> TYA?
.Loop
.^mainRamTransferTemplateLdaStaPair1
    LDA (transientOs4243SwrAddr),Y
    STA (transientOs4243MainAddr),Y
    DEY:BNE Loop

.LastByte
.^mainRamTransferTemplateLdaStaPair2
    LDA (transientOs4243SwrAddr),Y
    STA (transientOs4243MainAddr),Y
    LDA romselCopy
    STX romselCopy:STX romsel
    TAX
    RTS

    RELOCATE variableMainRamSubroutine, mainRamTransferTemplate
    ; SFTODO: Can maybe add a RELOCATE_CHECK which does following ASSERT (allowing for extra data where present)
    ASSERT P% - mainRamTransferTemplate <= variableMainRamSubroutineMaxSize
}

; Transfer Y+1 bytes between host (sideways RAM, starting at address in L00A8)
; and parasite (starting at address set up when initiating tube transfer before
; this code was called). The code is patched when it's transferred into RAM to
; do the transfer in the appropriate direction.
; SFTODO: If Y=255 on entry I think we will transfer 256 bytes, but double-check that later.
.tubeTransferTemplate
{
    ORG variableMainRamSubroutine

    TXA
    LDX romselCopy
    STA romselCopy:STA romsel
    INY:STY TransferSize
    LDY #0
.^tubeTransferReadSwr
.CopyLoop
.Full
    BIT tubeReg3Status:BVC Full
    LDA (transientOs4243SwrAddr),Y:STA tubeReg3Data
.^tubeTransferReadSwrEnd
    JSR Delay:JSR Delay:JSR Delay ; SFTODO: Inconsistent of using Delay vs Rts for labels like this?
    INY:CPY TransferSize:BNE CopyLoop
    LDA romselCopy
    STX romselCopy:STX romsel
    TAX
.Delay
    RTS

TransferSize = P% ; 1 byte

    RELOCATE variableMainRamSubroutine, tubeTransferTemplate
    ; There is a byte of space used at TransferSize when this copied into RAM but it's not
    ; present in the ROM, hence P% + 1 in the next line.
    ASSERT (P% + 1) - tubeTransferTemplate <= variableMainRamSubroutineMaxSize


; This fragment of code is copied over tubeTransferReadSwr to convert it into a write.
; SQUASH: The first three bytes (the BIT instruction) of patched code are the same either way,
; unless there's another hidden patch we could save three bytes by not patching those.
.^tubeTransferWriteSwr
.Empty
    BIT tubeReg3Status:BPL Empty
    LDA tubeReg3Data:STA (transientOs4243SwrAddr),Y
    ASSERT P% - tubeTransferWriteSwr == tubeTransferReadSwrEnd - tubeTransferReadSwr
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
IF IBOS_VERSION < 127
    LDA prvOswordBlockCopy + 2:STA L0100
    LDA prvOswordBlockCopy + 3:STA L0101
    LDA prvOswordBlockCopy + 4:STA L0102
    LDA prvOswordBlockCopy + 5:STA L0103
ELSE
    LDX #3
.CopyLoop
    LDA prvOswordBlockCopy+2,X:STA L0100,X
    DEX:BPL CopyLoop
ENDIF
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
    LDY #tubeTransferReadSwrEnd - tubeTransferReadSwr - 1
.PatchLoop
    LDA tubeTransferWriteSwr,Y
    STA tubeTransferReadSwr,Y
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
    STA mainRamTransferTemplateLdaStaPair1 + 1
    STA mainRamTransferTemplateLdaStaPair2 + 1
    LDA #transientOs4243SwrAddr
    STA mainRamTransferTemplateLdaStaPair1 + 3
    STA mainRamTransferTemplateLdaStaPair2 + 3
.Rts2
    RTS
}

; Relocation code then check for RAM in bank X.
; SFTODO: "Using..." part of name is perhaps OTT, but it might be important to "remind" us that
; this tramples over variableMainRamSubroutine - perhaps change later once more code is
; labelled up
.TestBankXForRamUsingVariableMainRamSubroutine
    TXA:PHA
    LDX #lo(TestRamTemplate):LDY #hi(TestRamTemplate):JSR CopyYxToVariableMainRamSubroutine
    PLA
    JMP variableMainRamSubroutine

;this routine is called by osword42 and osword43
;
;00F0 contains X reg for most recent OSBYTE/OSWORD
;00F1 contains Y reg for most recent OSBYTE/OSWORD
;where X contains low byte of the parameter block address
;and   Y contains high byte of the parameter block address. 
.copyOswordDetailsToPrv
{
    PRVEN
    ; ENHANCE/SQUASH: Note that we store Y on top of X; it should presumably be stored at
    ; prvOswordBlockOrigAddr + 1. We could fix this, but looking over the code I think this is
    ; only used for OSWORD &42/&43 and I don't believe they ever refer to
    ; prvOswordBlockOrigAddr anyway, so we could probably just remove these instructions.
    LDA oswdbtX:STA prvOswordBlockOrigAddr
    LDA oswdbtY:STA prvOswordBlockOrigAddr
    LDY #prvOswordBlockCopySize - 1
.CopyLoop
    LDA (oswdbtX),Y:STA prvOswordBlockCopy,Y
    DEY:BPL CopyLoop
    RTS
}
			
{
; SFTODO: *SRSAVE seems quite badly broken, I think because of problems with
; OSWORD &43.
; "*SRSAVE FOO A000 C000 4 Q" generates "Bad address" and saves nothing.
; "*SRSAVE FOO A000 C000 4" does seem to create the file correctly but then
; generates a "Bad address" error.
; SFTODO: Ken has pointed out those commands are (using Integra-B *SRSAVE conventions) trying
; to save one byte past the end of sideways RAM, hence "Bad address". I don't know if we should
; consider changing this to be more Acorn DFS SRAM utils-like in a new version of IBOS or not,
; but those actual commands do work fine if the end address is fixed. (We could potentially
; quibble about whether it's right that one of those error-generating command creates an empty
; file and the other doesn't, but I don't think this is a big deal, and I have no idea what
; Acorn DFS does either.)

;*SRSAVE Command
.^srsave
IF IBOS_VERSION < 127
    PRVEN
    LDA #&00 ; function "save absolute"
    JMP Common
ELSE
    LDA #&00 ; function "save absolute"
    ; Skip the next two bytes using BIT. This won't read from an I/O address as the high byte
    ; of its operand is &80.
    EQUB opcodeBitAbsolute
    ASSERT Common == P% + 2
ENDIF

;*SRLOAD Command
.^srload
IF IBOS_VERSION < 127
    PRVEN
ENDIF
    LDA #&80 ; function "load absolute"
.Common
IF IBOS_VERSION >= 127
    PRVEN ; preserves A
ENDIF
    STA prvOswordBlockCopy
    JSR getSrsaveLoadFilename
    JSR parseOsword4243BufferAddress
    BIT prvOswordBlockCopy:BMI NotSave ; test function
    JSR parseOsword4243Length
    ; SFTODO: Once the code is all worked out for both OSWORD &42 and &43, it's probably best
    ; to define constants e.g. prvOswordBlockCopyBufferLength = prvOswordBlockCopy + 6 and use
    ; those everywhere, instead of relying on comments on each line.
    LDA prvOswordBlockCopy + 6 ; low byte of buffer length
    STA prvOswordBlockCopy + 10 ; low byte of data length
    LDA prvOswordBlockCopy + 7 ; high byte of buffer length
    STA prvOswordBlockCopy + 11 ; high byte of data length
.NotSave
    JSR ParseBankNumberIfPresent
    JSR parseSrsaveLoadFlags
    LDA prvOswordBlockCopy + 2 ; byte 0 of "buffer address" we parsed earlier
    STA prvOswordBlockCopy + 8 ; low byte of sideways start address
    LDA prvOswordBlockCopy + 3 ; byte 1 of "buffer address" we parsed earlier
    STA prvOswordBlockCopy + 9 ; high byte of sideways start address
    BIT prvOswordBlockCopy + 7 ; SFTODO: document what's at this address
IF IBOS_VERSION >= 127
    JSR ensureOswordBlockBankIsUsableRamIfPossibleViaStarCmd
ENDIF
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
    XASSERT_USE_PRV1
    LDX prvOswordBlockCopy + 12 ; low byte of filename in I/O processor
    LDY prvOswordBlockCopy + 13 ; high byte of filename in I/O processor
    JSR OSFIND
    CMP #0:BEQ GenerateNotFoundErrorIndirect ; SQUASH: CMP #0->TAX/TAY? Depends if we can corrupt them...
    STA L02EE
    RTS

.CloseHandleL02EE
    LDA #osfindClose
    LDY L02EE
    JMP OSFIND

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
    JSR copyOswordDetailsToPrv
    JSR adjustPrvOsword42Block
.^osword42Internal
    XASSERT_USE_PRV1
    JSR getAddressesAndLengthFromPrvOswordBlockCopy
IF IBOS_VERSION < 127
    BCS LA0B1 ; SFTODO: I don't believe this branch can ever be taken
ELSE
    JSR ensureOswordBlockBankIsUsableRamIfPossibleViaOsword
ENDIF
    JSR PrepareMainSidewaysRamTransfer
    JSR doTransfer
.LA0B1
    PHP
    BIT prvTubeReleasePending:BPL NoTubeReleasePending
    LDA #tubeEntryRelease + tubeClaimId
    JSR tubeEntry
.NoTubeReleasePending
    JMP plpPrvDisexitSc
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
IF IBOS_VERSION >= 127
            JSR ensureOswordBlockBankIsUsableRamIfPossibleViaOsword
ENDIF
            LDA prvOswordBlockCopy + 6                                                              ;low byte of buffer length
            ORA prvOswordBlockCopy + 7                                                              ;high byte of buffer length
            BNE bufferLengthNotZero
            BIT prvOswordBlockCopy:BPL readFromSwr					;test if loading or saving
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

; A wrapper for ParseRomBankList which returns if at least one bank was parsed and generates an
; error otherwise. At the moment, this is used only by *INSERT and *UNPLUG.
.ParseRomBankListChecked
{
    JSR ParseRomBankList
    BCC Rts ; branch if no banks selected
    BVC GenerateSyntaxErrorIndirect
.^badId
    JSR RaiseError
    EQUB &80
	EQUS "Bad id", &00

.GenerateSyntaxErrorIndirect
    JMP GenerateSyntaxErrorForTransientCommandIndex

    ; SQUASH: Can we repurpose another nearby RTS and get rid of this?
.Rts
    RTS
}

{
;*INSERT Command
.^insert
    JSR ParseRomBankListChecked
    LDX #userRegBankInsertStatus + 0:JSR ReadUserReg:ORA transientRomBankMask + 0:JSR WriteUserReg
    ; SQUASH: Replace LDX # with ASSERT:INX?
    LDX #userRegBankInsertStatus + 1:JSR ReadUserReg:ORA transientRomBankMask + 1
    JSR WriteUserRegAndCheckNextCharI:BNE ExitAndClaimServiceCallIndirect1 ; branch if not 'I'
    INY ; skip 'I'
    JSR insertBanksUsingTransientRomBankMask
.ExitAndClaimServiceCallIndirect1
    JMP ExitAndClaimServiceCall

.WriteUserRegAndCheckNextCharI
    JSR WriteUserReg
    JSR FindNextCharAfterSpace
IF IBOS_VERSION < 127
    LDA (transientCmdPtr),Y ; Redundant. Included in JSR FindNextCharAfterSpace
ENDIF
    AND #CapitaliseMask
    CMP #'I' ; check for 'I' (Immediate)
    RTS

;*UNPLUG Command
.^unplug
    JSR ParseRomBankListChecked:JSR InvertTransientRomBankMask
    ; SFTODO: L00AE/L00AF are magic addresses
    LDX #userRegBankInsertStatus + 0:JSR ReadUserReg:AND L00AE:JSR WriteUserReg
    ; SQUASH: Replace LDX # with ASSERT:INX?
    LDX #userRegBankInsertStatus + 1:JSR ReadUserReg:AND L00AF
    JSR WriteUserRegAndCheckNextCharI:BNE ExitAndClaimServiceCallIndirect2 ; branch if not 'I'
    INY ; skip 'I'
    JSR unplugBanksUsingTransientRomBankMask
.ExitAndClaimServiceCallIndirect2
    JMP ExitAndClaimServiceCall
}

{
CurrentBank = TransientZP + 2
BankCopyrightOffset = TransientZP + 3
IF IBOS_VERSION >= 127
; PrintADecimal uses transientBin and transientBCD so we must fit round those.
RamPresenceCopyLow = TransientZP + 0
RamPresenceCopyHigh = TransientZP + 1
ENDIF


IF IBOS_VERSION < 127
.LA34A
    ; ENHANCE: We could go and test all the individual banks to see if they're RAM, rather than
    ; using this table and userRegRamPresenceFlags.
    EQUB &00								;ROM at Banks 0 & 1
    EQUB &00								;ROM at Banks 2 & 3
    EQUB &04								;Check for RAM at Banks 4 & 5
    EQUB &08								;Check for RAM at Banks 6 & 7
    EQUB &10								;Check for RAM at Banks 8 & 9
    EQUB &20								;Check for RAM at Banks A & B
    EQUB &40								;Check for RAM at Banks C & D
    EQUB &80								;Check for RAM at Banks E & F
ENDIF


;*ROMS Command
IF IBOS_VERSION < 127
.^roms
    LDA #maxBank:STA CurrentBank
.BankLoop
    JSR ShowRom
    DEC CurrentBank:BPL BankLoop
    JMP PrvDisExitAndClaimServiceCall2 ; SQUASH: BMI always, maybe to equivalent code nearer by?
			
; SQUASH: This has only one caller
.ShowRom
    LDA CurrentBank:CLC:JSR PrintADecimal ; show bank number right-aligned
    JSR printSpace
    LDA #'(':JSR OSWRCH
    LDA CurrentBank:LSR A:TAY
    ; Note that at least in IBOS 1.20, the low two bits of userRegRamPresenceFlags don't
    ; reflect sideways RAM, but the main 32K of RAM and the 32K of shadow/private RAM. This
    ; doesn't matter here because we mask it off using the table at LA34A.
    LDX #userRegRamPresenceFlags:JSR ReadUserReg
    AND LA34A,Y:BNE IsSidewaysRamBank ; branch if this is a sideways RAM bank
    LDA #' ':BNE BankTypeCharacterInA ; always branch
.IsSidewaysRamBank
    LDX CurrentBank:JSR TestBankXForRamUsingVariableMainRamSubroutine:PHP ; stash flags with Z set iff writeable
    LDA #'E' ; write-Enabled
    PLP:BEQ BankTypeCharacterInA
    LDA #'P' ; Protected
.BankTypeCharacterInA
    JSR OSWRCH
    PRVEN
    LDX CurrentBank:LDA RomTypeTable,X
    LDY #' ' ; not unplugged
    AND #&FE ; bit 0 of ROM type is undefined, so mask out
    ; SFTODO: If we take this branch, will we ever do PRVDIS?
   BNE ShowRomHeader
 ; The RomTypeTable entry is 0 so this ROM isn't active, but it may be one we've unplugged;
    ; if our private copy of the ROM type byte is non-0 show those flags.
    LDY #'U' ; Unplugged
    PRVEN ; SFTODO: We already did this, why do we need to do it again?
    LDA prvRomTypeTableCopy,X
    ; SFTODO: We don't AND #&FE here, is that wrong/inconsistent?
    PRVDIS
    BNE ShowRomHeader
    JSR printSpace ; ' ' in place of 'U'
    JSR printSpace ; ' ' in place of 'S'
    JSR printSpace ; ' ' in place of 'L'
    LDA #')':JSR OSWRCH
    JMP OSNEWL

ELSE
.^roms
    LDA #maxBank:STA CurrentBank

    LDX #userRegRamPresenceFlags0_7:JSR ReadUserReg:STA RamPresenceCopyLow
    ASSERT userRegRamPresenceFlags0_7 + 1 == userRegRamPresenceFlags8_F
    INX:JSR ReadUserReg:STA RamPresenceCopyHigh

.ShowRomLoop
    JSR ShowRom
    DEC CurrentBank:BPL ShowRomLoop
    JMP PrvDisExitAndClaimServiceCall2 ; SQUASH: BMI always, maybe to equivalent code nearer by?

.ShowRom
    LDA CurrentBank:CLC:JSR PrintADecimal ; show bank number right-aligned
    JSR printSpace
    LDA #'(':JSR OSWRCH

.IsSidewaysRamBank
    LDX CurrentBank:JSR TestBankXForRamUsingVariableMainRamSubroutine:PHP ; stash flags with Z set iff writeable
    LDA #'E' ; write-Enabled
    PLP:BEQ BankTypeCharacterInA
    LDA #'P' ; Protected
.BankTypeCharacterInA
    JSR OSWRCH ; Print the first status character (Protected / write-Enabled)
    LDY #'R' ; not unplugged
    LDX CurrentBank:LDA RomTypeTable,X
 ;   AND #&FE ; bit 0 of ROM type is undefined, so mask out 
 ; SFTODO: If we take this branch, will we ever do PRVDIS?
    BNE TestRrpFlagsForNonEmptyBank

 ; The RomTypeTable entry is 0 so this ROM isn't active, but it may be one we've unplugged;
    ; if our private copy of the ROM type byte is non-0 show those flags.
    LDY #'U' ; Unplugged
    PRVEN
    LDA prvRomTypeTableCopy,X
    PRVDIS
    BEQ TestRrpFlagsForEmptyBank
    ASL RamPresenceCopyLow:ROL RamPresenceCopyHigh ; Not used here, but need to rotate anyway.
    JMP ShowRomHeader
 
 .TestRrpFlagsForEmptyBank
    LDY #'R' ; Physical POM
    ASL RamPresenceCopyLow:ROL RamPresenceCopyHigh:BCC RamRomPalpromFlagCharacterInY
    JSR TestforPALPROM

.RamRomPalpromFlagCharacterInY
    TYA:JSR OSWRCH ; Print the second status character ('R','r' or 'p')
    JSR printSpace ; Print the third status character (' ' in place of 'S')
    JSR printSpace ; Print the forth status character (' ' in place of 'L')
    LDA #')':JSR OSWRCH
    JMP OSNEWL

.TestRrpFlagsForNonEmptyBank
    ASL RamPresenceCopyLow:ROL RamPresenceCopyHigh:BCC ShowRomHeader
    JSR TestforPALPROM
    FALLTHROUGH_TO ShowRomHeader
ENDIF

; Entered with Y=' ' or 'U' and rom type byte in A (IBOS < 127).
; Entered with Y=' ', 'p', 'r', 'R' or 'U' and rom type byte in A (IBOS >= 127).
.ShowRomHeader
    PHA
    TYA:JSR OSWRCH ; Print the second status character (' ', 'p', 'r', 'R' or 'U')
    LDX #'S' ; Service
    PLA:PHA:ASSERT RomTypeService == 1 << 7:BMI HasServiceEntry
    LDX #' '
.HasServiceEntry
    TXA:JSR OSWRCH ; Print the third status character ('S' or ' ')
    LDX #'L' ; Language
    PLA:AND #RomTypeLanguage:BNE HasLanguageEntry
    LDX #' '
.HasLanguageEntry
    TXA:JSR OSWRCH ; Print the forth status character ('L' or ' ')
    LDA #')':JSR OSWRCH
    JSR printSpace
    ; Print the ROM title and version.
IF IBOS_VERSION < 126
    LDA #lo(CopyrightOffset):STA osRdRmPtr:LDA #hi(CopyrightOffset):STA osRdRmPtr + 1
ELSE
    JSR SetOsRdRmPtrToCopyrightOffset
ENDIF
    LDY CurrentBank:JSR OSRDRM:STA BankCopyrightOffset
    LDA #lo(Title):STA osRdRmPtr:ASSERT hi(Title) == hi(CopyrightOffset)
.TitleAndVersionLoop
    LDY CurrentBank:JSR OSRDRM:BNE NotNul ; read byte and convert NUL at end of title to space
    LDA #' '
.NotNul
    JSR OSWRCH
    INC osRdRmPtr ; advance osRdRmPtr; we know the high byte isn't going to change
    LDA osRdRmPtr:CMP BankCopyrightOffset:BCC TitleAndVersionLoop
    JMP OSNEWL
IF IBOS_VERSION >= 126
.^SetOsRdRmPtrToCopyrightOffset
    LDA #lo(CopyrightOffset):STA osRdRmPtr:LDA #hi(CopyrightOffset):STA osRdRmPtr + 1
    RTS
ENDIF
}

IF IBOS_VERSION >= 127
.TestforPALPROM
{
    LDY #'r' ; onboard RAM
; Firstly, test for V2 hardware...
    PHA
    JSR testV2hardware
    BCC endpptest
    LDA cpldPALPROMSelectionFlags0_7 ; PALPROM Flags
; Then test if PALPROM in banks 8..11
    CPX #8:BCC endpptest
    CPX #12:BCS endpptest ; 8<=X<12
    AND palprom_test_table-8,X:BEQ endpptest
    LDY #'p' ; onboard PALPROM
.endpptest
    pla
    rts
.^RegRamMaskTable
    EQUB &01 ; bank 8
; note that RegRamMaskTable overlaps with the first three bytes of palprom_test_table; they should be 2, 4 & 8 for banks 9..11.
; This should probably be validated with an ASSERT
.^palprom_test_table
    EQUB &02 ; bank 8  - PALPROM 2a is enabled when cpldPALPROMSelectionFlags0_7 bit 1 is set
    EQUB &04 ; bank 9  - PALPROM 2b is enabled when cpldPALPROMSelectionFlags0_7 bit 2 is set
    EQUB &08 ; bank 10 - PALPROM 4a is enabled when cpldPALPROMSelectionFlags0_7 bit 3 is set
    EQUB &40 ; bank 11 - PALPROM 8a is enabled when cpldPALPROMSelectionFlags0_7 bit 5 is set
.^palprom_banks_table
    EQUB &01 ; bank 8 - PALPROM 2a has 1 extra bank
    EQUB &01 ; bank 9 - PALPROM 2b has 1 extra bank
    EQUB &07 ; bank 10 - PALPROM 4a has 3 extra banks
    EQUB &7F ; bank 11 - PALPROM 8a has 7 extra banks
}

; Test for V2 hardware. Carry is set if V2 hardware detected, otherwise carry is cleared.
.testV2hardware
{
    LDA #0:JSR Common:CMP #&60:BNE ClcRts ; On Break, cpldRAMROMSelectionFlags0_3_V2Status[7:5] = 3'b011
    ; We didn't BNE, so we know A is &60, and since &60>=&60 we know the CMP set carry.
    LDA #3:JSR Common:BNE ClcRts
    ; Carry still set from CMP above.
    RTS

.Common
    STA cpldExtendedFunctionFlags
    LDA cpldRAMROMSelectionFlags0_3_V2Status
    AND #&E0
    RTS
}
ENDIF

; Parse a list of bank numbers, returning them as a bitmask in transientRomBankMask. '*' can be
; used to indicate "everything but the listed banks". Return with C clear iff at least one bit
; of transientRomBankMask is set.
.ParseRomBankList
{
    LDA #0:STA transientRomBankMask:STA transientRomBankMask + 1
.ParseLoop
    JSR ParseBankNumber:BCS NoBankNumber
    JSR addToRomBankMask
    JMP ParseLoop
.NoBankNumber
    LDA (transientCmdPtr),Y
    CMP #'*':BNE NotStar
    ; This BVS will branch if an invalid bank has been specified on the command line - V will
    ; have been populated to indicate this by ParseBankNumber. I assume the idea here is that
    ; inverting is dangerous if an undefined pseudo-bank was specified on the command line,
    ; which may or may not be sensible.
    ;
    ; ENHANCE: Because we only check V here, if you do *SRSET 4 (so only pseudo bank W is
    ; defined) and then *INSERT X,4 you get a bad ID error (because X is an invalid bank and
    ; terminates processing while no banks are set, so C is set on exit), but *INSERT 4,X just
    ; silently ignores the X.  One fix for this would be to do this BVS immediately after the
    ; NoBankNumber label, *but* that would break callers (such as - probably - *SRWE) which
    ; need to be able to parse an apparently invalid bank as a trailing option like "T".
    ;
    ; SFTODONOW *SRSET IS NOT PRESERVED ON CTRL BREAK IS THIS RIGHT?
    BVS SecRts
    INY
    JSR InvertTransientRomBankMask
.NotStar
    LDA transientRomBankMask:ORA transientRomBankMask + 1:BEQ SecRts
.^ClcRts
    CLC
    RTS

; SQUASH: There's probably another copy of these two instructions we could re-use, though it
; might require shuffling code round and be more trouble than it's worth
.SecRts
    SEC
    RTS
}

{
; Set the 16-bit word at transientRomBankMask to 1<<A, i.e. set it to 0 then set bit A. Y is
; preserved.
; SQUASH: Am I missing something, or wouldn't it be far easier just to do a 16-bit rotate left
; in a loop? Maybe that wouldn't be shorter. Maybe this is performance critical? (Doubt it)
.^createRomBankMask
    PHA
    LDA #0:STA transientRomBankMask:STA transientRomBankMask + 1
    PLA

; Set bit A of the 16-bit word at transientRomBankMask. Y and V are preserved.
.^addToRomBankMask
    TAX:TYA:PHA:TXA ; push Y, preserving A
    LDX #0
    CMP #8:BCC LowByte
    LDX #1 ; SQUASH: INX
.LowByte
    AND #7:TAY
    LDA #0
    SEC
.Loop
    ROL A
    DEY:BPL Loop
    ORA transientRomBankMask,X:STA transientRomBankMask,X
    PLA:TAY
    RTS
}

; Parse a bank number from the command line, converting pseudo banks W-Z into the corresponding
; absolute bank numbers. If a bank is parsed successfully, return with C and V clear and the
; bank in A. If a bank is not parsed successfully, return with C set; V will be set iff the
; problem was the use of an invalid bank number (>15 or a pseudo bank with no associated
; absolute bank).
; ENHANCE: While not a huge problem, this will not detect an error if given a bank number which
; doesn't fit in 8 bits.
; SFTODO: Maybe check callers agree with this understanding of return convention?
.ParseBankNumber
{
    ; SQUASH: Would it be more compact to check for W-Z *first*, then use
    ; ConvertIntegerDefaultHex? This might only work if we do a "proper" upper case conversion,
    ; not sure.
    JSR FindNextCharAfterSpace:BCS EndOfLine
IF IBOS_VERSION < 127
    LDA (transientCmdPtr),Y ; Redundant. Included in JSR FindNextCharAfterSpace
ENDIF
    CMP #',':BNE NotComma
    INY
.NotComma
    JSR ConvertIntegerDefaultDecimal:BCC ParsedDecimalOK
    LDA (transientCmdPtr),Y:AND #CapitaliseMask
    CMP #'F'+1:BCS MaybePseudo
    CMP #'A':BCC SecClvRts
    SBC #'A'-10:JMP ParsedBank ; SQUASH: could probably do "BPL ; always" to save a byte
.MaybePseudo
    CMP #'Z'+1:BCS SecClvRts
    CMP #'W':BCC SecClvRts
    SBC #'W'
    CLC:ADC #prvPseudoBankNumbers - prv83:TAX:JSR ReadPrivateRam8300X
.ParsedBank
    INY
.ParsedDecimalOK
    ; This branch is taken if prvPseudoBankNumbers contains &FF for the relevant pseudo bank or
    ; if the user specifies an out-of-range bank directly.
    CMP #maxBank+1:BCS SevRts
.EndOfLine
    CLV
    RTS
			
.SecClvRts
    SEC
    CLV
    RTS
			
.SevRts
    BIT Rts ; set V
.Rts
    RTS
}

{
.^createRomBankMaskAndInsertBanks
    JSR createRomBankMask
; Read ROM type from ROM header for ROMs with a 1 bit in transientRomBankMask and save to the
; OS ROM type table and our private copy. This is used to immediately *INSERT ROMs without
; waiting for BREAK.
.^insertBanksUsingTransientRomBankMask
    PRVEN
    LDY #maxBank
.BankLoop
    ASL transientRomBankMask:ROL transientRomBankMask + 1:BCC SkipBank
    LDA #lo(RomType):STA osRdRmPtr:LDA #hi(RomType):STA osRdRmPtr + 1
    TYA:PHA:JSR OSRDRM:TAX:PLA:TAY:TXA \ read byte at osRdRmPtr from bank Y into A, preserving Y
    STA RomTypeTable,Y:STA prvRomTypeTableCopy,Y
.SkipBank
    DEY:BPL BankLoop
    PRVDIS
    RTS
}

; Set bytes in the ROM type table to 0 for banks with a 0 bit in transientRomBankMask; other
; banks are not touched.
.unplugBanksUsingTransientRomBankMask
{
    LDY #maxBank
.Loop
    ASL transientRomBankMask:ROL transientRomBankMask + 1:BCS SkipBank
    LDA #0:STA RomTypeTable,Y
.SkipBank
    DEY:BPL Loop
    RTS
}

; Invert the bits in transientRomBankMask.
.InvertTransientRomBankMask
    LDA transientRomBankMask:EOR #&FF:STA transientRomBankMask
    LDA transientRomBankMask + 1:EOR #&FF:STA transientRomBankMask + 1
    RTS

; Assign default pseudo RAM banks to absolute RAM banks.
; For OSMODEs other than 2: W..Z = 4..7
; For OSMODE 2: W..Z = 12..15
; SQUASH: This has only one caller
; The OSMODE 2 behaviour is presumably intended to support an installation where IBOS is in
; IC101 (bank 3) and four additional RAM chips have been installed to give sideways RAM in
; banks 12-15. Note that OSMODE 4 is like OSMODE 2 but with the standard allocation of pseudo
; to absolute RAM banks.
.assignDefaultPseudoRamBanks
{
    PRVEN
    LDA prvOsMode
    LDX #3 ; SFTODO: mildly magic, 4 pseudo banks
    LDY #7; for OSMODEs other than 2, absolute banks are 4..7
    CMP #2:BNE NotOsMode2
    LDY #maxBank ; if OSMODE is 2, absolute banks are 12..15
.NotOsMode2
.Loop
    TYA:STA prvPseudoBankNumbers,X
    DEY:DEX:BPL Loop
    JMP PrvDis
}

{
; SFTODO: This little fragment of code is only called once via JMP, can't it just be moved to avoid the JMP (and improve readability)?
.^LA4FE
    JSR createRomBankMask
    SEC
    PHP
    JMP LA513 ; SQUASH: BCS always? Or move this code and just fall through?
			
;*SRWE Command
.^srwe
    CLC:BCC Common ; always branch

;*SRWP Command
.^srwp
    SEC
.Common
    PHP
IF IBOS_VERSION >= 127
    JSR testV2hardware:BCC v2Only
ENDIF
    ; SFTODONOW: Could/should this use one of the ParseRomBankListChecked subroutines? Of
    ; course we do not want to do write protect, *SRDATA or PALPROM checks here, so be careful
    ; as these routines are tweaked.
    JSR ParseRomBankList:BCC LA513
    JMP badId
			
.LA513
IF IBOS_VERSION < 127
    LDX #userRegBankWriteProtectStatus:JSR ReadUserReg
ELSE
    LDX #userRegBankWriteProtectStatus
    JSR FindNextCharAfterSpaceSkippingComma
    BCS NoOption
    AND #CapitaliseMask
    CMP #'T'
    BNE NoOption
    ; We implement temporary changes by redirecting the WriteUserReg calls to two bytes of
    ; temporary space instead of the correct registers.
    LDX #userRegTmp
.NoOption
    LDA cpldRamWriteProtectFlags0_7
ENDIF
    ORA L00AE
    PLP
    PHP
    BCC LA520
    EOR L00AE
.LA520
IF IBOS_VERSION < 127
    JSR WriteUserReg
    INX
    JSR ReadUserReg
ELSE
    STA cpldRamWriteProtectFlags0_7
    JSR WriteUserReg
    LDA cpldRamWriteProtectFlags8_F
ENDIF
    ORA L00AF
    PLP
    BCC LA52E
    EOR L00AF
.LA52E
IF IBOS_VERSION < 127
    JSR WriteUserReg
    PRVEN
    JSR SFTODOWRITEPROTECTISH
.^PrvDisExitAndClaimServiceCall2
    PRVDIS
ELSE
    STA cpldRamWriteProtectFlags8_F
    INX:JSR WriteUserReg
ENDIF
    JMP ExitAndClaimServiceCall
}

IF IBOS_VERSION >= 127
.v2Only
    JSR RaiseError
    EQUB &80
    EQUS "V2 Only", &00
ENDIF

IF IBOS_VERSION < 127
; SFTODO: What's going on here? This seems to be writing to RTC register %1xxxxxxx and
; %x1xxxxxx, which I'm not even sure exist. The use of userRegBankWriteProtectStatus is
; obviously a clue, but the code doesn't seem to be doing anything obviously sensible with
; those values.
.SFTODOWRITEPROTECTISH
{
    XASSERT_USE_PRV1
    LDX #userRegBankWriteProtectStatus:JSR ReadUserReg:STA prvTmp
    INX:JSR ReadUserReg
    PHP:SEI
    LSR A:ROR prvTmp
    LSR A:ROR prvTmp
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
ENDIF

IF IBOS_VERSION >= 127
.DoOsbyteKeyboardScanFrom10
    LDA #osbyteKeyboardScanFrom10:JMP OSBYTE
ENDIF

;SPOOL/EXEC file closure warning - Service call 10 SFTODO: I *suspect* we are using this as a "part way through reset" service call rather than for its nominal purpose - have a look at OS 1.2 disassembly and see when this is actually generated. Do filing systems or anything issue it during "normal" operation? (e.g. if you do "*EXEC" with no argument.)
; NB: On a BBC B with OS 1.20 (which is the only relevant case for IBOS), the very first
; service call issued on power on is this one. (It occurs inside the call to "JSR
; .setupTapeOptions", using TobyLobster's disassembly labels.)
.service10
{
    ; SFTODO: I'm guessing, but note that during a typical boot service call &10 is issued
    ; early, then there will be a service call &03, then a subsequent service call &10 once the
    ; filing system has been selected. service03 sets SQWE. So maybe this is saying "on the
    ; early service call &10, start at SoftReset, but on the second service call &10, execute
    ; this additional code at SQWESet". But that only works if something (hardware tied to the
    ; reset line???) clears SQWE first. Maybe this is something related to detecting power-on
    ; reset, though why we suddenly don't trust lastBreakType I don't know - maybe this is too
    ; early for that to have been set, though that seems unlikely.
    SEC:JSR AlarmAndSQWEControl:BCS SQWESet
    JMP SoftReset ; SQUASH: BCC always? SFTODO: Rename this label given its use here?
.SQWESet
    LDA ramselCopy:AND #ramselShen:STA ramselCopy

    PRVEN

IF IBOS_VERSION < 127
    JSR SFTODOWRITEPROTECTISH
ENDIF

    ; Copy the OS ROM type table into private RAM so we know the original contents before we modified it.
    LDX #maxBank
.CopyLoop
    LDA RomTypeTable,X:STA prvRomTypeTableCopy,X
    DEX:BPL CopyLoop

    PRVDIS

    LDX lastBreakType:BEQ SoftReset
IF IBOS_VERSION < 127
    LDA #osbyteKeyboardScanFrom10:JSR OSBYTE
ELSE
    JSR DoOsbyteKeyboardScanFrom10
ENDIF
    CPX #keycodeAt:BNE SoftReset ; SFTODO: Rename label given use here?
    ; The last break wasn't a soft reset and the "@" key is held down, which will trigger a
    ; full reset.
    ; SQUASH: If we use X instead of A here, we could replace "LDA #&FF" with DEX to save a byte.
    LDA #0:STA breakInterceptJmp ; cancel any break intercept which might have been set up
    LDA #&FF:STA FullResetFlag ; record that a full reset is in progress
    ; SFTODO: Seems superficially weird we do this ROM type manipulation in response to this particular service call
    ; Set the OS ROM type table and our private RAM copy to zero for all ROMs except us. SFTODO: why?
    LDX #maxBank
.ZeroLoop
    CPX romselCopy:BEQ SkipBank
     ; SFTODO: are we confident romselCopy doesn't have b7/b6 set?? To be fair, this is probably *very* early in boot and the OS has paged us in, so almost certainly this is fine.
    LDA #0:STA RomTypeTable,X:STA romPrivateWorkspaceTable,X
.SkipBank
    DEX:BPL ZeroLoop
    JMP Finish ; SQUASH: BMI always

    ; SFTODO: Seems superficially weird we do this ROM type manipulation in response to this particular service call
.SoftReset
    LDA #0:STA FullResetFlag ; record that a full reset isn't in progress
    LDX #userRegBankInsertStatus:JSR ReadUserReg:STA transientRomBankMask
    LDX #userRegBankInsertStatus + 1:JSR ReadUserReg:STA transientRomBankMask + 1
    JSR unplugBanksUsingTransientRomBankMask
.Finish
IF IBOS_VERSION >= 127
    ; Check if IBOS is running on V2 hardware, and if it is then:
    ;  - read RAM / ROM flags from CPLD, and save to private RAM.
    ;  - read 'default' Write Protect flags from CPLD, and save to RTC CMOS. These will be used during IBOS Reset
    ;  - read the PALPROM config flags from private RAM, and write these to the CPLD
    ;  - read the 'in-use' Write Protect flags from private RAM, and write these to the CPLD
    ; Note that the private RAM register for the PALPROM config flags must be updated with *FX162,49,x 
    ;
    ; Otherwise, if using V1 hardware the private RAM should be updated
    ; with *FX162,126,x & *FX162,127,x to reflect the amount of on board RAM.
    JSR testV2hardware
    BCC notV2hardware
    LDA cpldRAMROMSelectionFlags0_3_V2Status:ORA #&F0:LDX #userRegRamPresenceFlags0_7:JSR WriteUserReg
    ASSERT userRegRamPresenceFlags0_7 + 1 == userRegRamPresenceFlags8_F
    INX:LDA cpldRAMROMSelectionFlags8_F:JSR WriteUserReg
    ; Read 'default' Write Protect flags from CPLD, and save to RTC CMOS. These will be used during IBOS Reset. 
    ; LDA cpldRamWriteProtectFlags0_7
    ; LDX #userDefaultRegBankWriteProtectStatus:JSR WriteUserReg
    ; LDA cpldRamWriteProtectFlags8_F
    ; INX:JSR WriteUserReg
    ; Read the PALPROM config flags from private RAM, and write these to the CPLD
    LDX #userRegPALPROMConfig:JSR ReadUserReg
    STA cpldPALPROMSelectionFlags0_7
    ; Read the 'in use' Write Protect flags from private RAM, and write these to the CPLD
    LDX #userRegBankWriteProtectStatus:JSR ReadUserReg
    STA cpldRamWriteProtectFlags0_7
    INX:JSR ReadUserReg
    STA cpldRamWriteProtectFlags8_F
.notV2hardware
ENDIF
; SFTODO: Next bit of code is either claiming or not claiming the service call based on prvTubeOnOffInProgress; it will return with A=&10 (this call) or 0.
    LDX #prvTubeOnOffInProgress - prv83:JSR ReadPrivateRam8300X
    EOR #&FF
    AND #&10
    TSX:STA L0103,X	; modify stacked A, i.e. A we will return from the service call with
    JMP ExitServiceCall
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
    LDA #0:STA prvDC + 1
    LDX #8
.Loop
    ASL A:ROL prvDC + 1
    ASL prvB:BCC NoAdd
    CLC:ADC prvA
    INCCS prvDC + 1
.NoAdd
    DEX:BNE Loop
    STA prvDC
    RTS
}

; Divide 16-bit value at prvBA by the 8-bit value at prvC, returning the result in prvD and the
; remainder in A. *Except* that if prvB>=prvC on entry, we return with prvD set to prvA and A
; set to prvB.
; SFTODO: I am not really sure about this prvB>=prvC condition; I think this might be detecting
; the case where the result won't fit in 8 bits, but even if it is, I don't see why those
; return values are helpful. As it happens I don't believe any div168 caller can
; actually trigger this behaviour and SQUASH: if that's true, the check could be removed.
; SQUASH: Several callers do "LDA #0:STA prvBA + 1" before calling this; we could have an
; alternate entry point div88 which does that before falling through into div168 to avoid
; duplicating that common code.
.div168
{
    XASSERT_USE_PRV1
    LDX #8 ; 8-bit division
    ; If prvB>=prvC, return with prvD=prvA, A=prvB.
    LDA prvBA:STA prvD
    LDA prvBA + 1
    CMP prvC:BCS Rts ; SFTODO: branch if prvB>=prvC
    ; SFTODO: Set prvD=prvA DIV prvC, A=prvA MOD prvC
.Loop
    ROL prvD:ROL A
    CMP prvC:BCC NeedBorrow
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
    ; SFTODO: This seems to leave SQWE off; during boot AlarmAndSQWEControl seems to be used to
    ; turn it on. There doesn't seem to be any obvious logic to this.
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

IF IBOS_VERSION < 126
; Dead code
{
.CopyPrvDateTimeToRtc
    JSR CopyPrvTimeToRtc
    JMP CopyPrvDateToRtc
}
ENDIF

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
IF IBOS_VERSION == 120 AND IBOS120_VARIANT == 0
    EQUB 2  ; rtcRegDayOfWeek: Monday
ELSE
    EQUB 7  ; rtcRegDayOfWeek: Saturday
ENDIF
    EQUB 1  ; rtcRegDayOfMonth: 1st
    EQUB 1  ; rtcRegMonth: January
    EQUB 0  ; rtcRegYear: 1900 SFTODO: presumably this means 2000 in IBOS 1.21? does any other code need to change?
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

; SQUASH: This has two callers, one of which does CLC and the other SEC before calling it. So
; just split it into two separate subroutines and get rid of the use of C on entry to choose
; behaviour.
.AlarmAndSQWEControl
{
Tmp = TransientZP + 6

    BCS GetSQWE
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
.GetSQWE
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

IF IBOS_VERSION < 126
; Dead code
{
    LDA prvOswordBlockCopy + 13
    BPL LA904
    CMP #&8C
    BNE LA8FC
    LDA #&00
    BEQ LA901
.LA8FC
    AND #&7F
    CLC
    ADC #&0C
.LA901
    STA prvOswordBlockCopy + 13
.LA904
    RTS
}
ENDIF

; SFTODO: the "in" in the next two exported labels is maybe confusing, "storeTo" might be better but even more longwinded - anyway, just a note for when I finally clean up all the label names
{
TmpMonth = prvTmp4
TmpYear = prvTmp3
TmpCentury = prvTmp2

; As CalculateDayOfWeekInA, except we also update prvDateDayOfWeek with the calculated day of
; the week, and set SFTODO:PROBABLY b3 of prvDateSFTODOQ if this changes prvDateDayOfWeek from
; its previous value.
.^CalculateDayOfWeekInPrvDateDayOfWeek
    CLC:BCC Common ; always branch SQUASH: "BCC Common"->"LDA #" opcode to skip the following SEC?
; Calculate the day of the week for the date in prvDate* and return with it in A.
.^CalculateDayOfWeekInA
    SEC
.Common
    XASSERT_USE_PRV1
    PHP ; save C on entry for later use
    ; SFTODO: I don't claim to fully understand the algorithm used here so I've added comments
    ; which document the calculations the code is carrying out to make it easier to see what's
    ; going on but without pretending they fully explain why it works. I can sort of see how
    ; it works though:
    ; - We simplify leap year handling by pretending the year starts in March, so leap days
    ; - occur at the end of the year, not part way through it.
    ; - We "accumulate" a value in prvA and only ultimately care about prvA mod 7, but as long as
    ;   we don't overflow we can add things which cause prvA mod 7 to move appropriately. Except
    ;   for leap years, any given date is one day of the week later each year, so we can add the
    ;   year number in to take this into account, for example.

    ; Convert the supplied date into one where the year starts in March; TmpMonth is the month
    ; number in this adjusted calendar, with 1=March and 12=February, and the year/century are
    ; in Tmp{Year,Century}.
    LDA prvDateYear:STA TmpYear
    LDA prvDateCentury:STA TmpCentury
    SEC:LDA prvDateMonth:SBC #2:STA TmpMonth
    BMI JanuaryOrFebruary ; branch if prvDateMonth is January
    CMP #1:BCS DateAdjustedForMarchBasedYear ; branch if March or later
.JanuaryOrFebruary
    CLC:ADC #12:STA TmpMonth ; TmpMonth = prvDateMonth + 10
    DEC TmpYear:BPL DateAdjustedForMarchBasedYear ; branch if wasn't year 0
    CLC:LDA TmpYear:ADC #100:STA TmpYear ; SQUASH: Just do "LDA #99:STA TmpYear"?
    ; SQUASH: Is the following branch always taken? Don't we really only support 19xx/20xx dates?
    DEC TmpCentury:BPL DateAdjustedForMarchBasedYear
    CLC:LDA TmpCentury:ADC #100:STA TmpCentury
.DateAdjustedForMarchBasedYear

    ; Set prvA = (TmpMonth*130*2-19) DIV 100. It just so happens that prvA MOD 7 is then the day
    ; of the week (with some fixed offset needed for any particular year) which TmpMonth starts on.
    ; - For March 2022 we have TmpMonth=1 so prvA=2. March 2022 starts on a Tuesday.
    ; - For December 2022 we have TmpMonth=10 so prvA=25=4 (mod 7). December 2022 starts on a
    ;   Thursday, which is two days later than Tuesday, and note that the prvA mod 7 value is
    ;   two larger the value calculated for March 2022.
    ; - For February 2023 we have TmpMonth=12 so prvA=31=3 (mod 7). Given the above, we'd expect
    ;   February 2023 to start on a Wednesday, and it does.
    ; I have checked this for all 12 months against the 2022-23 calendar and the formula gives the
    ; right result for each one. I don't know where the formula comes from, presumably someone
    ; sat down and played around until they found something that happened to work.
    LDA TmpMonth:STA prvA
    LDA #130:STA prvB
    JSR mul8 ; DC=A*B
    ASL prvDC:ROL prvDC + 1
    SEC
    LDA prvDC    :SBC #lo(19):STA prvBA
    LDA prvDC + 1:SBC #hi(19):STA prvBA + 1
    ; We have BA = TmpMonth*130*2-19.
    LDA #100:STA prvC
    ; This div168 call can't invoke the strange "prvB >= prvC" case, because TmpMonth<=12 so
    ; prvB<=hi(12*130*2-19)<=12.
    JSR div168
    ; The result is in prvD and we know prvD <= (12*130*2-19)/100 == 31.

    ; Adjust prvA based on prvDateDayOfMonth, TmpYear and TmpCentury. I don't pretend to
    ; understand the precise logic here, but this is effectively shifting the day of week value
    ; we just calculated so that it uses a "standard" day numbering. It's important we don't
    ; overflow our 8-bit range here (because 256 is not a multiple of 7); the comments in
    ; brackets show the worst case to demonstrate that we won't overflow.

    ; prvA = prvD + prvDateDayOfMonth + TmpYear (wc: 31+31+99=161)
    CLC:LDA prvD:ADC prvDateDayOfMonth:ADC TmpYear:STA prvA
    ; prvA += TmpYear/4 (wc: 161+99/4=185)
    LDA TmpYear:LSR A:LSR A:CLC:ADC prvA:STA prvA
    ; A = prvA + (TmpCentury/4) (wc: 185+99/4=209)
    LDA TmpCentury:LSR A:LSR A:CLC:ADC prvA
    ; A -= TmpCentury*2
    ASL TmpCentury:SEC:SBC TmpCentury
    ; That subtraction might have underflowed, so do some fix up if it did.
    PHP
    BCS NoUnderflow1
    SEC:SBC #1:EOR #&FF ; negate A SQUASH: we know C is clear, so omit SEC and do SBC #0?
.NoUnderflow1

    ; Set A = A MOD 7.
    STA prvBA
    LDA #0:STA prvBA + 1
    LDA #daysPerWeek:STA prvC
    JSR div168 ; prvB == 0, prvC == 7, so the "prvB >= prvC" case can't occur

    PLP
    BCS NoUnderflow2
    SEC:SBC #1:EOR #&FF ; negate A SQUASH: as above
    CLC:ADC #daysPerWeek
.NoUnderflow2
    CMP #daysPerWeek
    BCC InRange
    SBC #daysPerWeek
.InRange

    ; Bump A by 1; this is probably to convert from the 0-based day-of-week numbering which is
    ; natural when working mod 7 to 1-based day-of-week numbering elsewhere in the code.
    ; SQUASH: Do we need to update prvA here? Shorter to do "SEC:SBC #1" if we can make it
    ; work. Or maybe we could PHA here and then PLA later. This isn't utterly trivial.
    STA prvA:INC prvA:LDA prvA

    PLP:BCS Rts ; test stacked flags from entry; C set => return result in A
    ; Return result in A and at prvDateDayOfWeek; test to see if the existing value was correct
    ; and update prvDateSFTODOQ if it wasn't. SFTODO: I think that comment is a touch glib. I'm
    ; not 100% confident yet but a lot of the time SFTODOQ is about errors - but the way we
    ; behave here seems odd from that POV, we *set* the bit if the existing value wasn't right,
    ; but then we update prvDateDayOfWeek so it *is* right, which means the bit we just set
    ; indicates "was wrong but is no longer wrong". I suspect this is being used to indicate
    ; something like "open" or "didn't match user's specification". It may be that the updated
    ; value is not relevant in some/all cases where we use this code path.
    CMP prvDateDayOfWeek:BEQ LA9DF
    ; SFTODO: I think it's right to be using the SFTODOQ labels here but not sure yet
    LDA #prvDateSFTODOQDayOfWeek:ORA prvDateSFTODOQ:STA prvDateSFTODOQ
.LA9DF
    LDA prvA:STA prvDateDayOfWeek
.Rts
    RTS
}

; We output month calendars with 7 rows for Sun-Sat and up to 6 columns; to see 6 columns may
; be needed, consider a 31-day month where the 1st is a Saturday. Populate the buffer pointed
; to by prvDateSFTODO4 so elements 0-6 are the day numbers to display in row 0 (the day numbers
; of the Sundays), elements 7-13 are the day numbers to dispay in row 1 (the day numbers of the
; Mondays), etc, for a total of 6*7=42 elements. Blank cells contain day number 0.
.GenerateInternalCalendar
{
; SFTODO: 7 ROWS, 6 COLUMNS ARE KEY NUMBERS HERE AND WE SHOULD PROBABLY BE CALCULATING SOME NAMED CONSTANTS (EG 42) FROM OTHER NAMED CONSTANTS WHICH ARE 6 AND 7
daysInMonth = transientDateSFTODO2

    XASSERT_USE_PRV1
    LDA #1:STA prvDateDayOfMonth
    JSR CalculateDayOfWeekInPrvDateDayOfWeek
    LDY prvDateMonth:JSR GetDaysInMonthY:STA daysInMonth
.makePrvDateDayOfWeekGe37Loop
    CLC:LDA daysInMonth:ADC prvDateDayOfWeek
    CMP #37:BCS prvDateDayOfWeekGe37
    CLC:LDA prvDateDayOfWeek:ADC #7:STA prvDateDayOfWeek
    JMP makePrvDateDayOfWeekGe37Loop ; SQUASH: BPL always?
.prvDateDayOfWeekGe37
    LDA prvDateSFTODO4:STA transientDateSFTODO1
    LDA prvDateSFTODO4 + 1:STA transientDateSFTODO1 + 1
    LDA #0
    LDY #42
.zeroBufferLoop
    DEY:STA (transientDateSFTODO1),Y:BNE zeroBufferLoop
    INC daysInMonth ; bump daysInMonth so the following loop can use a strictly less than comparison
.DayOfMonthLoop
    ; SQUASH: BCS to a nearby RTS (there's one just above) to save a byte
    LDA prvDateDayOfMonth:CMP daysInMonth:BCC notDone
    RTS
.notDone
    ADC prvDateDayOfWeek
    SEC:SBC #2:STA prvBA
    LDA #0:STA prvBA + 1
    LDA #7:STA prvC
    JSR div168 ; strange "prvB >= prvC" case can't occur
    STA prvA ; SFTODO: we are setting A = (prvDateDayOfWeek + 2) MOD 7 - though remember we adjusted prvDateDayOfWeek above for currently unclear reasons (I suspect they're something to do with blanks in the first column of dates, ish)
    LDA #6:STA prvB
    LDA prvD:PHA ; SFTODO: stash result of division as mul8 will corrupt prvD
    JSR mul8 ; SFTODO: prvDC = 6 * the A we calculated above
    PLA:CLC:ADC prvC:TAY ; SFTODO: add the stashed pseudo-division result to the low byte of the multiplication we just did (we *probably* know the high byte in prvD is zero and can be ignored)
    LDA prvDateDayOfMonth:STA (transientDateSFTODO1),Y
    INC prvDateDayOfMonth
    JMP DayOfMonthLoop ; SQUASH: BPL always?
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
IF IBOS_VERSION >= 126
.^MonthNameOffsetTable
ENDIF
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
    EQUB End       - DayMonthNames ; SFTODO: is this entry used? probably, just a thought...
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
    ; Set X and EndCalOffset so the string to print is at DayMonthNames+[X, EndCalOffset).
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
TensChar = prvTmp2
UnitsChar = prvTmp3

; Emit A (<=99) into transientDateBuffer, formatted as a decimal number according to X:
;   A    0     5     25
; X=0 => "00"  "05"  "25"  Right-aligned in two character field, leading 0s
; X=1 => "0"   "5"   "25"  Left-aligned with no padding, 1 or 2 characters
; X=2 => " 0"  " 5"  "25"  Right-aligned in two character field, no leading 0s
; X=3 => "  "  " 5"  "25"  Right-aligned in two character field, no leading 0s, 0 shown as blank
.^EmitADecimalFormatted ; SFTODO: should have ToDateBuffer in name
    JSR ConvertAToTensUnitsChars
    LDY transientDateBufferIndex
    CPX #0:BEQ PrintTensChar ; SQUASH: TXA instead of CPX #0
    LDA TensChar:CMP #'0':BNE PrintTensChar
    CPX #1:BEQ SkipLeadingZero ; SQUASH: DEX:BEQ?
    LDA #' ':STA TensChar
    LDA UnitsChar:CMP #'0':BNE PrintTensChar
    CPX #3:BNE PrintTensChar ; SQUASH: #3 needs changing if use DEX above
    LDA #' ':STA UnitsChar
.PrintTensChar
    LDA TensChar:STA (transientDateBufferPtr),Y:INY
.SkipLeadingZero
    LDA UnitsChar:JMP EmitAToDateBufferUsingY

; Suffixesfor dates, e.g. 25th, 1st, 2nd, 3rd
.dateSuffixes
    EQUS "th", "st", "nd", "rd"

; Emit ordinal suffix for A (<=99) into transientDateBuffer; if C is set it will be capitalised.
; SQUASH: This only has one caller, can it just be inlined?
.^EmitOrdinalSuffix
    XASSERT_USE_PRV1
    PHP
    JSR ConvertAToTensUnitsChars
    LDA TensChar:CMP #'1':BNE Not1x
.ThSuffix
    LDX #0:JMP SuffixInX ; SQUASH: Could BEQ ; always
.Not1x
    LDA UnitsChar
    CMP #'4':BCS ThSuffix
    AND #&0F ; convert ASCII digit to binary
    ASL A:TAX ; X=units digit*2=index into dateSuffixes
.SuffixInX
    PLP
    LDY transientDateBufferIndex
    LDA dateSuffixes,X
    BCC NoCaps1
    AND #CapitaliseMask
.NoCaps1
    STA (transientDateBufferPtr),Y:INY
    LDA dateSuffixes + 1,X
    BCC NoCaps2
    AND #CapitaliseMask
.NoCaps2
    JMP EmitAToDateBufferUsingY

; Convert binary value in A to two-digit ASCII representation at TensChar/UnitsChar.
.ConvertAToTensUnitsChars
    LDY #&FF
    SEC
.TensLoop
    INY
    SBC #10:BCS TensLoop
    ADC #10:ORA #'0':STA UnitsChar
    TYA:ORA #'0':STA TensChar
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
; SQUASH: EmitAmPmForHourA is a bit more complex than necessary - here's a shorter alternative
; implementation, not tested!
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
    LDX #0 ; X is formatting option for EmitADecimalFormatted; 0 means "00" style.
    ; SQUASH: Omit EOR and use BEQ instead of BNE?
    AND #prvDateSFTODO2NoLeadingZero:EOR #prvDateSFTODO2NoLeadingZero:BNE LeadingZero
    INX:INX ; X=2 => EmitADecimalFormatted will use " 0" style
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
    JSR EmitADecimalFormatted
    LDA #':':JSR EmitAToDateBuffer

.ShowMinutes
    LDX #0 ; X is formatting option for EmitADecimalFormatted; 0 means "00" style.
    LDA Options
    CMP #prvDateSFTODO2UseHours:BCS ShowMinutesAs00 ; branch if hour shown
    CMP #prvDateSFTODO212Hour:BEQ ShowMinutesAs00 ; branch if 24 hour clock
    ; Options could be 0, 2 or 3 here but I suspect in practice it will either be 0 or 2, and
    ; thus this is effectively using prvDateSFTODO2NoLeadingZero to select "00" or " 0" format.
    TAX ; X is formatting option for EmitADecimalFormatted
.ShowMinutesAs00
    LDA prvDateMinutes:JSR EmitADecimalFormatted
    LDA Options
    CMP #prvDateSFTODO2MinutesControl:BCC separatorColon
    CMP #prvDateSFTODO2MinutesControl OR prvDateSFTODO2UseHours:BCC ShowAmPm
    LDA #'/'
    BNE separatorInA ; always branch
.separatorColon
    LDA #':'
.separatorInA
    JSR EmitAToDateBuffer
    LDX #0:LDA prvDateSeconds:JSR EmitADecimalFormatted ; emit seconds using "00" format

.ShowAmPm
    LDA Options:CMP #prvDateSFTODO2UseHours:BCC Finish
    LDA Options:AND #prvDateSFTODO212Hour:BEQ Finish ; SQUASH: "LDA options" is redundant
    LDA #' ':JSR EmitAToDateBuffer
    LDA prvDateHours:JSR EmitAmPmForHourA
.Finish
    CLC
    RTS
}

{
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
.^emitDateToDateBuffer ; SFTODO: "date" here as in "the day identifier, omitting any time indicator within that day"
    XASSERT_USE_PRV1
; SFTODO: Experimentally using nested scopes here to try to make things clearer, by making it more obvious that some labels have restricted scope - not sure if this is really helpful, let's see
; SFTODO: Chopping the individual blocks up into macros might make things clearer?
; 1. Optionally emit the day of the week, optionally truncated and/or capitalised, and optionally followed by some punctuation. prvDataSFTODO2's high nybble controls most of those options, although prvDataSFTODO3=0 will prevent punctuation and cause an early return.
    {
	  LDA prvDateSFTODO2
IF IBOS_VERSION < 126
      LSR A:LSR A:LSR A:LSR A
ELSE
      JSR LsrA4
ENDIF
      STA transientDateSFTODO1
      BEQ SFTODOSTEP2
      AND #1
      EOR #1
      TAY
      LDA transientDateSFTODO1
      LDX #&00
      CMP #&05
      BCS maxCharsInX
      LDX #3
      CMP #3
      BCS maxCharsInX
      DEX
.maxCharsInX
      ; Emit prvDateDayOfWeek's name with a maximum of X characters; Y controls capitalisation.
	  LDA prvDateDayOfWeek:CLC:JSR EmitDayOrMonthName
      LDA prvDateSFTODO3
      BNE LACA0
      JMP LAD5Arts

.LACA0
      LDA prvDateSFTODO1
      AND #&0F
      STA transientDateSFTODO1
      CMP #&04
      BCC LACB6
      LDA #',':JSR EmitAToDateBuffer
      LDA transientDateSFTODO1
      CMP #&08
      BCC SFTODOSTEP2
.LACB6
      LDA #' ':JSR EmitAToDateBuffer
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
.LACD0
        LDA prvDateDayOfMonth
        JSR EmitADecimalFormatted ; X controls formatting
        LDA transientDateSFTODO1
        CMP #&04
        BCC LACE5
        BEQ LACDF
        CLC ; don't capitalise
.LACDF
        LDA prvDateDayOfMonth:JSR EmitOrdinalSuffix
.LACE5
        LDA prvDateSFTODO3
        AND #&F8
        BEQ LAD5Arts
        LDA prvDateSFTODO1
        AND #&03
        TAX
        LDA dateSeparators,X
        JSR EmitAToDateBuffer
    }
; 3. Look at b3-5 of prvDateSFTODO3; if they're 0, jump to step 4. Otherwise emit the month with optional formatting. Then stop if b5-6 of prvDateSFTODO3 are 0. Otherwise emit a dateSeparator based on low two bits of prvDateSFTODO1.
.SFTODOSTEP3MAYBE
    {
        LDA prvDateSFTODO3
        LSR A:LSR A:LSR A
        AND #&07
        STA transientDateSFTODO1
        BEQ SFTODOSTEP4MAYBE
        CMP #&04
        BCS LAD18
        LDX #&00
        CMP #&03
        BEQ formatInX
        TAX
.formatInX
        LDA prvDateMonth:JSR EmitADecimalFormatted ; X controls formatting
        JMP LAD2A

.LAD18
        LDX #&03
        CMP #&06
        BCC LAD20
        LDX #&00
.LAD20
        AND #&01
        TAY
        ; Emit prvDateMonth's name with a maximum of X characters; Y controls capitalisation.
        LDA prvDateMonth:SEC:JSR EmitDayOrMonthName
.LAD2A
        LDA prvDateSFTODO3
        AND #&C0
        BEQ LAD5Arts
        LDA prvDateSFTODO1
        AND #&03
        TAX
        LDA dateSeparators,X:JSR EmitAToDateBuffer
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
        LDA prvDateCentury:JSR EmitADecimalFormatted
.emitYear
        LDX #&00
        LDA prvDateYear:JMP EmitADecimalFormatted

.^LAD5Arts
        RTS

.emitCenturyTick
        LDA #''':JSR EmitAToDateBuffer
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
    LDA #0:STA prvDateSFTODOX
    SEC:LDA prvDateCentury:SBC #19:BCC Error ; fail for dates before 1900
    BEQ CenturyAdjustInA
    CMP #1:BNE Error ; fail for dates after 2099
    LDA #100
.CenturyAdjustInA
    CLC:ADC prvDateYear
    ; A now contains YearsSince1900=four digit year-1900.
    ; Set prvDC = YearsSince1900*lo(daysPerYear); prvDC+1 might be as high as 84 if
    ; YearsSince1900=199
    PHA:STA prvA
    LDA #lo(daysPerYear):STA prvB
    JSR mul8
    ; Set prvDC += YearsSince1900*hi(daysPerYear)*256, noting hi(daysPerYear) == 1.
    ; ENHANCE: Note this may overflow, e.g. if YearsSince1900=199, prvDC+1 should be
    ; 84+199=283, but we don't check.
    CLC:PLA:PHA:ADC prvDC + 1:STA prvDC + 1
    ; At this point prvDC = YearsSince1900*daysPerYear. Set prvDC += YearsSince1900 DIV 4.
    PLA:LSR A:LSR A:CLC:ADC prvDC:STA prvDC
    LDA prvDC + 1:ADC #0:STA prvDC + 1 ; SQUASH: Use INCCS - careful with folllowing BCS...
    BCS Error ; branch if we've overflowed
    ; At this point prvDC = YearsSince1900*daysPerYear + YearsSince1900 DIV 4 = days since
    ; January 1st 1900. ENHANCE: I'm not sure this is right - even with the TYA->TAX bug fix in
    ; ConvertDateToRelativeDayNumber, date.bas test still fails. I think the problem might be
    ; that we should be adding "(YearsSince1900-1) DIV 4" not "YearsSince1900 DIV 4", since in
    ; January 1904 the leap day has not occurred yet, and we should leave it to
    ; ConvertDateToRelativeDayNumber to take the leap day for the current year into account.
    JSR ConvertDateToRelativeDayNumber
    CLC
    LDA prvDateSFTODO4:ADC prvDC:STA prvDateSFTODO4
    LDA prvDateSFTODO4 + 1:ADC prvDC + 1:STA prvDateSFTODO4 + 1
    BCS Error ; branch if we've overflowed
    ; We have now (EHNANCE: ignoring bug in ConvertDateToRelativeDayNumber) calculated the
    ; number of days from January 1st 1900 to prvDate.
    RTS
			
.Error
    LDA #&FF
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
    JMP CalculateDayOfWeekInPrvDateDayOfWeek
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
    JSR CalculateDayOfWeekInA:STA prvDateDayOfWeek
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
    JSR CalculateDayOfWeekInA:STA prvDateDayOfWeek
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
    STA prvBA
    LDA #0:STA prvBA + 1
    LDA #7:STA prvC
    JSR div168 ; SFTODO: WILL ALWAYS DIVIDE WITH NO WEIRDNESS
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
    JSR CalculateDayOfWeekInA:CMP prvDateDayOfWeek:BEQ LB0C1
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
    JSR CalculateDayOfWeekInA
    CMP prvDateDayOfWeek
    BNE LB0CD
    BEQ LB07B ; always branch
.LB0DA
    JSR DecrementPrvDateBy1
    JSR CalculateDayOfWeekInA
    CMP prvDateDayOfWeek
    BNE LB0DA
    BEQ LB07B ; always branch
.LB0E7
    JSR CalculateDayOfWeekInA
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
    JSR CalculateDayOfWeekInA
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
    JSR CalculateDayOfWeekInA
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
    JSR FindNextCharAfterSpace
IF IBOS_VERSION < 127
    LDA (transientCmdPtr),Y ; Redundant. Included in JSR FindNextCharAfterSpace
ENDIF
    CMP #vduCr:BEQ DateArgumentParsed
    ; Otherwise parse the command line and fill in prvDate* accordingly.
    JSR SFTODOProbParsePlusMinusDate:BCS BadDate:STA prvDateDayOfWeek
    CMP #&FF:BEQ DayOfWeekOpen
    ; The user has specified a day of the week; if there's no trailing comma this is the end of
    ; the user-specified partial date.
    JSR FindNextCharAfterSpace
IF IBOS_VERSION < 127
    LDA (transientCmdPtr),Y ; Redundant. Included in JSR FindNextCharAfterSpace
ENDIF
    CMP #',':BNE DateArgumentParsed
    INY ; skip ','
.DayOfWeekOpen
    JSR ConvertIntegerDefaultDecimal:BCC DayOfMonthInA
    LDA #&FF ; day of month is open
.DayOfMonthInA
    STA prvDateDayOfMonth
    ; After the day of the month there may be a '/' followed by month/year components; if
    ; there's no '/' we have finished parsing the user-specified partial date.
    JSR FindNextCharAfterSpace
IF IBOS_VERSION < 127
    LDA (transientCmdPtr),Y ; Redundant. Included in JSR FindNextCharAfterSpace
ENDIF
    CMP #'/':BNE DateArgumentParsed
    INY ; skip '/'
    JSR ConvertIntegerDefaultDecimal:BCC MonthInA
    LDA #&FF ; month is open
.MonthInA
    STA prvDateMonth
    ; After the month there may be a '/' followed by a year component; if there's no '/' we have finished parsing the user-specified partial date.
    JSR FindNextCharAfterSpace
IF IBOS_VERSION < 127
    LDA (transientCmdPtr),Y ; Redundant. Included in JSR FindNextCharAfterSpace
ENDIF
    CMP #'/':BNE DateArgumentParsed
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
IF IBOS_VERSION < 126
    LSR A:LSR A:LSR A:LSR A
ELSE
    JSR LsrA4
ENDIF
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
    LDA ConvertIntegerResult    :STA prvBA
    LDA ConvertIntegerResult + 1:STA prvBA + 1
    LDA #100:STA prvC
    JSR div168 ; SFTODO: IN PRACTICE THIS WILL ALWAYS DO DIVISION WITH NO WEIRDNESS (9999 WOULD GIVE PRVB=39<100)
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
    JSR FindNextCharAfterSpace
IF IBOS_VERSION < 127
    LDA (transientCmdPtr),Y ; Redundant. Included in JSR FindNextCharAfterSpace
ENDIF
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

; Parse a date from the command line, populating PrvDate* and returning with C clear iff
; parsing succeeds. From v1.26 Y is updated to point to the next character after successful
; parsing; it is corrupted in earlier versions.
.ParseAndValidateDate
{
    XASSERT_USE_PRV1
    LDA #0:STA prvDateDayOfWeek
    JSR ConvertIntegerDefaultDecimal:BCS ParseError:STA prvDateDayOfMonth
IF IBOS_VERSION < 126
    LDA (transientCmdPtr),Y:INY
    CMP #'/':BNE ParseError
ELSE
    JSR ParseSlashOrSpace:BNE ParseError
ENDIF
    JSR ConvertIntegerDefaultDecimal
IF IBOS_VERSION < 126
    BCS ParseError
ELSE
currentMonth = transientCmdPtr + 2
savedY = transientCmdPtr + 3
charsToMatch = transientCmdPtr + 4
    BCC MonthInA
    ; We couldn't parse the month as an integer, but it may be a three character month name. We
    ; implement this for the benefit of OSWORD &0F, but this also means *DATE= will accept it,
    ; which seems like a reasonable bonus rather than a problem. As the main motivation for
    ; this is OSWORD &0F, we don't attempt to accept longer versions of the month name.
    LDA #MonthsPerYear:STA currentMonth
    STY savedY
.MonthLoop
    ; -1 in the next line as currentMonth is 1-based but MonthNameOffset is 0-based.
    LDY currentMonth:LDX MonthNameOffsetTable-1,Y
    LDY savedY
    LDA #3:STA charsToMatch
.MonthCharLoop
    LDA (transientCmdPtr),Y:ORA #LowerCaseMask:CMP DayMonthNames,X:BNE NoMatch
    INY:INX:DEC charsToMatch:BNE MonthCharLoop
    LDA currentMonth:BNE MonthInA ; always branch
.NoMatch
    DEC currentMonth:BNE MonthLoop
.ParseError
    SEC
    RTS
.MonthInA
ENDIF
    STA prvDateMonth
IF IBOS_VERSION < 126
    LDA (transientCmdPtr),Y:INY
    CMP #'/':BNE ParseError
ELSE
    JSR ParseSlashOrSpace:BNE ParseError
ENDIF
    JSR ConvertIntegerDefaultDecimal:BCS ParseError
IF IBOS_VERSION >= 126
    ; We use this for parsing OSWORD &0F date strings, so we need to preserve Y so parsing can
    ; continue after the date.
    STY savedY
ENDIF
    JSR InterpretParsedYear
    JSR ValidateDateTimeAssumingLeapYear
    LDA prvDateSFTODOQ:AND #prvDateSFTODOQCenturyYearMonthDayOfMonth:BNE ParseError
    JSR CalculateDayOfWeekInPrvDateDayOfWeek
IF IBOS_VERSION >= 126
    LDY savedY
ENDIF
    CLC
    RTS

IF IBOS_VERSION < 126
.ParseError
    SEC
    RTS
ENDIF

IF IBOS_VERSION >= 126
.ParseSlashOrSpace
    LDA (transientCmdPtr),Y:INY
    CMP #'/':BEQ Rts
    CMP #' '
.Rts
    RTS
ENDIF
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
IF IBOS_VERSION >= 127
.^PrvDisExitAndClaimServiceCall2
ENDIF
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
CellIndex = prvB ; current element in the 42-element structure generated by GenerateInternalCalendar
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
    JSR GenerateInternalCalendar
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
    LDX #3:JSR EmitADecimalFormatted ; emit A with 0 formatted as "  " and 5 as " 5"
    INC CellIndex
    INC Column:LDA Column:CMP #6:BCC ColumnLoop ; SFTODO: prob use one of named constants I plan to introduce in GenerateInternalCalendar
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
    JSR FindNextCharAfterSpace
IF IBOS_VERSION < 127
    LDA (transientCmdPtr),Y ; Redundant. Included in JSR FindNextCharAfterSpace
ENDIF
    AND #CapitaliseMask:CMP #'R'
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
IF IBOS_VERSION < 126
    LDA oswdbtX:STA prvOswordBlockOrigAddr
    LDA oswdbtY:STA prvOswordBlockOrigAddr + 1
ENDIF
    JSR oswordsv
    JSR oswd0e_1
    BCS osword0ea
    JSR oswordrs
.osword0ea
IF IBOS_VERSION < 126
    ; Restore oswdbt[AXY]. This isn't necessary, as we haven't modified them, and we might
    ; actually be allowed to corrupt them anyway given we're claiming the call.
    LDA prvOswordBlockOrigAddr:STA oswdbtX
    LDA prvOswordBlockOrigAddr + 1:STA oswdbtY
    LDA #&0E:STA oswdbtA
ENDIF
    PRVDIS
    JMP RestoreTransientZPAndExitAndClaimServiceCall
}

;OSWORD &49 (73) - Integra-B calls
{
.^osword49
    JSR SaveTransientZP
    PRVEN
IF IBOS_VERSION < 126
    LDA oswdbtX:STA prvOswordBlockOrigAddr
    LDA oswdbtY:STA prvOswordBlockOrigAddr + 1
ENDIF
    JSR oswordsv ; save the OSWORD block
    JSR oswd49_1 ; execute the OSWORD call
    BCS Success
    JSR oswordrs ; restore the OSWORD block if we failed
.Success
IF IBOS_VERSION < 126
    ; Restore oswdbt[AXY]. This isn't necessary, as we haven't modified them, and we might
    ; actually be allowed to corrupt them anyway given we're claiming the call.
    LDA prvOswordBlockOrigAddr:STA oswdbtX
    LDA prvOswordBlockOrigAddr + 1:STA oswdbtY
    LDA #&49:STA oswdbtA
ENDIF
    PRVDIS
.^RestoreTransientZPAndExitAndClaimServiceCall
    JSR RestoreTransientZP
    JMP ExitAndClaimServiceCall
}
			
;Save OSWORD XY entry table
{

.^oswordsv ; SFTODO: rename
    XASSERT_USE_PRV1
IF IBOS_VERSION < 126
Ptr = &AE
    LDA prvOswordBlockOrigAddr:STA Ptr
    LDA prvOswordBlockOrigAddr + 1:STA Ptr + 1
    LDY #prvOswordBlockCopySize - 1
.Loop
    LDA (Ptr),Y:STA prvOswordBlockCopy,Y
    DEY:BPL Loop
    RTS
ELSE
    LDA oswdbtX:STA prvOswordBlockOrigAddr
    LDA oswdbtY:STA prvOswordBlockOrigAddr + 1
    LDY #prvOswordBlockCopySize - 1
.Loop
    LDA (oswdbtX),Y:STA prvOswordBlockCopy,Y
    DEY:BPL Loop
    RTS
ENDIF
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
    ; ENHANCE: I think this will crash if we see an unsupported function code; we could check
    ; it's <=2 and make this a no-op in that case.
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
    JSR GenerateInternalCalendar
    LDA #42:STA prvDateSFTODO1 ; SFTODO: magic (=42=max size of resulting buffer - see GenerateInternalCalendar - ?)
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
;
; We use this to implement OSWRSC. OSWRSC at &FFB3 is only supported by OS 2.00 upwards; on OS
; 1.20 &FFB3 is fortuitously a 0 byte - a BRK opcode - in the middle of an "LDY &FE00,X"
; instruction at &FFB2. We implement OSWRSC when we receive this service call to notify us of a
; BRK at that address. Nifty!
.^service06
    ; The OS BRK handler puts the address of the byte following the BRK at osErrorPtr.
    LDA osErrorPtr + 1:CMP #hi(OSWRSC + 1):BNE ExitServiceCallIndirect
    ; SFTODO: I'm still not sure why we don't test the low byte of osErrorPtr here, instead of
    ; going through all the following first.
    LDX osBrkStackPointer:TXS
    ; At this point the stack looks like this:
    ;   &101,S  X stacked by OS BRK handler
    ;   &102,S  flags stacked by BRK
    ;   &103,S  return address stacked by BRK (low)
    ;   &104,S  return address stacked by BRK (high)
    ;   &105,S  top byte of stack in code executing BRK
    ; Note that none of the following PHA operations alter X (of course), so we have the S for
    ; the above stack picture in X.
    LDA #lo(osReturnFromRom - 1):PHA
    LDA L0102,X:PHA ; push original flags stacked by BRK
    LDA osIrqA:PHA ; push original A saved by OS interrupt handler
    LDA L0101,X:PHA ; push original X saved by OS BRK handler
    LDA #hi(osReturnFromRom - 1):STA L0101,X
    LDA romActiveLastBrk:STA L0102,X
    LDA osErrorPtr:CMP #lo(OSWRSC + 1):BEQ LB936
.LB931
    PLA:TAX ; restore original X from the value we pushed above
    PLA ; restore original A from the value we pushed above
    PLP ; restore original flags from the value we pushed above
    ; At this point the stack looks like this:
    ;   &101,S  &88 == lo(osReturnFromRom - 1)
    ;   &102,S  &FF == hi(osReturnFromRom - 1)
    ;   &103,S  romActiveLastBrk
    ;   &104,S  return address stacked by BRK (low)
    ;   &105,S  return address stacked by BRK (high)
    ;   &106,S  top byte of stack in code executing BRK
    ; The following RTS will therefore transfer control to &FF89 in the OS, called
    ; returnFromROM in TobyLobster's disassembly. This will re-select the ROM number on the
    ; stack (romActiveLastBrk here) and discard the stacked BRK address, executing RTS with the
    ; "top byte of stack in code executing BRK" at the top of the stack, which will return from
    ; the *assumed* JSR which caused the BRK. Note that we execute this code even if the check
    ; of the low byte of osErrorPtr above *doesn't* match OSWRSC, so SFTODO: I am a little
    ; unsure why this is always a reasonable thing to do. In practice we probably never get a
    ; BRK occurring from page &FFxx unless it's this one caused by trying to call OSWRSC.
    RTS
			
.LB936
    ; Set MEMSEL; this will force main/video memory to appear at &3000-8000 regardless of SHEN.
    ; We will revert to the previous setting when ROMSEL is restored to the contents of the
    ; stacked copy of romActiveLastBrk inside osReturnFromRom.
    LDA romselCopy:ORA #romselMemsel:STA romselCopy:STA romsel
    TSX:LDA L0102,X ; get original A
    STA (osWrscPtr),Y
    JMP LB931
}

; Set MEMSEL. This means that main/video memory will be paged in at &3000-&7FFF
; regardless of SHEN.
; SFTODO: Maybe change this to something like pageInMainVideoMemory? But for now
; it's probably better to make the hardware paging operation the focus.
.setMemsel
    PHA
    LDA romselCopy:ORA #romselMemsel:STA romselCopy:STA romsel
    PLA
    RTS

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
; which subroutine?). The code at romCodeStubCallIBOS pages us in, calls the VectorEntry
; subroutine and then pages the previous ROM back in afterwards. VectorEntry is able to
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
; SFTODO: Also worth noting this means we know romsel has none of the high bits set inside our
; vector handlers; presumably the same is also true when we're entered via a service call
; because the OS will page us in with those bits clear. In a few places in the code it
; superficially looks as though we would break if fg application happened to have high bits
; set, but it wouldn't (unless there's something lurking somewhere I've missed).
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
    JSR VectorEntry
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
; The stack must have the same layout as described in the big comment in VectorEntry; note that
; the addresses in this subroutine are two bytes higher because we were called via JSR so we
; need to allow for our own return address on the stack.
.RestoreOrigVectorRegs
{
    TSX
    LDA VectorEntryStackedFlags+2,X:PHA
    LDA VectorEntryStackedA+2,X:PHA
    LDA VectorEntryStackedX+2,X:PHA
IF IBOS_VERSION < 126
    LDA VectorEntryStackedY+2,X:TAY
ELSE
    LDY VectorEntryStackedY+2,X
ENDIF
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
    ; At this point the stack is as described in the big comment in VectorEntry but with the
    ; return address for this subroutine also pushed onto the stack.
    PHP
    PHA
    TXA:PHA
    ; So at this point the stack is as described in the big comment in VectorEntry but with
    ; everything moved up five bytes (X=S-5, if S is the value of the stack pointer in that
    ; comment).
    TYA:TSX:STA VectorEntryStackedY+5,X
    PLA:STA VectorEntryStackedX+5,X
    PLA:STA VectorEntryStackedA+5,X
    PLA:STA VectorEntryStackedFlags+5,X
    RTS
}

; Table of vector handlers used by VectorEntry; addresses have -1 subtracted because we
; transfer control to these via an RTS instruction. The odd bytes between the addresses are
; there to match the spacing of the JSR instructions at osPrintBuf; the actual values are
; irrelevant and will never be used.
; SFTODO: Are they really unused? Maybe there's some code hiding somewhere, but nothing
; references this label except the code at VectorEntry. It just seems a bit odd these bytes
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
.VectorEntry
{
    TXA:PHA
    TYA:PHA
    ; At this point the stack looks like this:
    ;   &101,S  Y stacked by preceding instructions
    ;   &102,S  X stacked by preceding instructions
    ;   &103,S  return address from "JSR VectorEntry" (low)
    ;   &104,S  return address from "JSR VectorEntry" (high)
    ;   &105,S  previously paged in ROM bank stacked by romCodeStubCallIBOS
    ;   &106,S  flags stacked by romCodeStubCallIBOS
    ;   &107,S  A stacked by romCodeStubCallIBOS
    ;   &108,S  return address from "JSR ramCodeStubCallIBOS" (low)
    ;   &109,S  return address from "JSR ramCodeStubCallIBOS" (high)
    ;   &10A,S  xxx (caller's data; nothing to do with us)
    ; The VectorEntryStacked* constants correspond to these addresses.
    ;
    ; The low byte of the return address at &108,S will be the address of the JSR
    ; ramCodeStubCallIBOS plus 2. We mask off the low bits (which are sufficient to distinguish
    ; the 7 different callers) and use them to transfer control to the handler for the relevant
    ; vector.
    TSX:LDA L0108,X:AND #&3F:TAX ; SFTODO: add a VectorEntryStacked* constant? prob not if only one use...
    LDA vectorHandlerTbl-1,X:PHA
    LDA vectorHandlerTbl-2,X:PHA
    RTS
}

; Clean up and return from a vector handler; we have dealt with the call and we're not going to
; call the parent handler. At this point the stack should be exactly as described in the big
; comment in VectorEntry; note that this code is reached via JMP so there's no extra return
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
    ;   &101,S  Y stacked by VectorEntry
    ;   &102,S  X stacked by VectorEntry
    ;   &103,S  return address from "JSR VectorEntry" (low)
    ;   &104,S  return address from "JSR VectorEntry" (high)
    ;   &105,S  previously paged in ROM bank stacked by romCodeStubCallIBOS
    ;   &106,S  flags stacked by romCodeStubCallIBOS
    ;   &107,S  A stacked by romCodeStubCallIBOS
    ;   &108,S  xxx (caller's data; nothing to do with us)
    ;
    ; We now restore Y and X and RTS from "JSR VectorEntry" in ramCodeStub, which will restore
    ; the previously paged in ROM, the flags and then A, so the vector's caller will see the
    ; Z/N flags reflecting A, but otherwise preserved.
    PLA:TAY
    PLA:TAX
    RTS
}

; Restore the registers and pass the call onto the parent vector handler for vector A (using
; the ibos*Index numbering). At this point the stack should be exactly as described in the big
; comment in VectorEntry; note that this code is reached via JMP so there's no extra return
; address on the stack as there is in RestoreOrigVectorRegs.
.forwardToParentVectorTblEntry
    TSX
    ASL A:TAY
    ; We need to subtract 1 from the destination address because we're going to transfer
    ; control via RTS, which will add 1. We overwrite the return address from "JSR
    ; ramCodeStubCallIBOS" on the stack.
    SEC
    LDA parentVectorTbl,Y:SBC #1:STA L0108,X ; SFTODO: L0108->name+n?
    LDA parentVectorTbl+1,Y:SBC #0:STA L0109,X ; SFTODO: L0109->name+n?
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

; OSBYTE &98 has different behaviour in OS 1.20 and OS 2.00 onwards, so we have to implement
; the OS 2.00 behaviour if we're in OSMODE>=2.
;
; In OS 1.20, for non-empty buffers, OSBYTE &98 returns with Y set so "LDA (&FA),Y" will
; retrieve the next character from the buffer.
;
; In OS 2.00, for non-empty buffers, OSBYTE &98 returns with Y containing the next character
; from the buffer.
;
; ENHANCE: It's important to bear in mind when reading the following that OSBYTE &98 can be
; used for any buffer, not just the printer buffer. That said, when it is called for the
; printer buffer, I suspect the code here is buggy. Note that we steal the RAM used by the OS
; printer buffer for ramCodeStub except in OSMODE 0, so forwarding the call on to the parent
; BYTEV is unlikely to give a correct result, and nor is accessing anything via the pointer at
; L00FA. A correct implementation would probably handle the printer buffer as a special case,
; using CheckPrintBufferEmpty and LdaPrintBufferReadPtr.
;
; In OSMODE 1, we'd probably need to store the next character in a spare byte of main RAM, set
; &FA to point to that spare byte and return with Y=0 in order for the caller to be able to see
; the character. (The real buffer is in private RAM and won't be visible to the caller whatever
; we set &FA and Y to.) The AUG says interrupts should be disabled when calling OSBYTE &98 and
; retrieving the character so we would probably get away with this.
;
; In practice OSBYTE &98 is probably not used to query the state of the printer buffer very
; much, and I believe this code will work correctly and emulate the appropriate OS behaviour in
; all OSMODEs for all buffers other than the printer buffer.
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
    ; SQUASH: The fact this updates the original registers, including A, for OSBYTE seems both
	; wrong and wasteful of space. The fact we do this means our individual OSBYTE routines tend
	; to waste space loading their own number back into A before finishing.
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
IF IBOS_VERSION < 127
    LDA #ModeChangeStateSeenVduSetMode:STA ModeChangeState
ELSE
    ; We know ModeChangeState is 0 here, because we didn't take the BNE at the start of
    ; WrchvHandler. So we can set it to ModeChangeStateSeenVduSetMode (1) with an INC.
    ASSERT ModeChangeStateSeenVduSetMode == 1
    INC ModeChangeState
ENDIF
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
    ; ENHANCE/DELETE: There seems to be an undocumented feature of IBOS which will perform a
    ; horizontal screen shift (analogous to the vertical shift controlled by *TV/*CONFIGURE TV)
    ; based on userRegHorzTV. This is not exposed in *CONFIGURE/*STATUS, but it does seem to
    ; work if you use *FX162,54 to write directly to the RTC register. In a modified IBOS this
    ; should probably either be removed to save space or exposed via *CONFIGURE/*STATUS.
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
Ptr = &A8
ScreenStart = &3000

; SFTODO: The next two subroutines are probably effectively saying "do nothing if the shadow
; state hasn't changed, otherwise do SwapShadowIfShxEnabled". I have given them poor names for
; now and should revisit this once exatly when they're called becomes clearer.
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
    LDA Ptr:PHA:LDA Ptr + 1:PHA
    LDA #lo(ScreenStart):STA Ptr:LDA #hi(ScreenStart):STA Ptr + 1
    LDY #0
.Loop
    LDA (Ptr),Y:TAX
    LDA romselCopy:EOR #romselMemsel:STA romselCopy:STA romsel
    LDA (Ptr),Y:PHA
    TXA:STA (Ptr),Y
    LDA romselCopy:EOR #romselMemsel:STA romselCopy:STA romsel
    PLA:STA (Ptr),Y
    INY:BNE Loop
    INC Ptr + 1:BPL Loop ; loop until we hit &8000
    PLA:STA Ptr + 1:PLA:STA Ptr
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

    JSR InitPrintBuffer ; claims additional vectors

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
.pageInPrvs81Rts
    RTS

IF IBOS_VERSION >= 127
; Y contains the vector index. Y is not corrupted here by IBOS versions <= 1.26, but it's fine,
; because Y carries no useful information in to INSV, REMV or CNPV and is preserved by our
; vector handling framework on exit unless we specifically modify it.
.BufferVHandlerCommon
{
    TSX:LDA VectorEntryStackedX+2,X ; get original X=buffer number, +2 to allow for JSR to us
    CMP #bufNumPrinter:BEQ pageInPrvs81Rts
    PLA:PLA ; discard stacked return address
    TYA:JMP forwardToParentVectorTblEntry
}
ENDIF

.InsvHandler
{
IF IBOS_VERSION < 127
    TSX:LDA VectorEntryStackedX,X ; get original X=buffer number
    CMP #bufNumPrinter:BEQ IsPrinterBuffer
    LDA #ibosINSVIndex:JMP forwardToParentVectorTblEntry

.IsPrinterBuffer
ELSE
    LDY #ibosINSVIndex:JSR BufferVHandlerCommon
ENDIF
    PRVS81EN
    PHA
    TSX
    JSR CheckPrintBufferFull:BCC PrintBufferNotFull
    ; Return to caller with carry set to indicate insertion failed.
    LDA VectorEntryStackedFlags+1,X:ORA #flagC:STA VectorEntryStackedFlags+1,X
    JMP RestoreRamselClearPrvenReturnFromVectorHandler

.PrintBufferNotFull
    LDA VectorEntryStackedA+1,X ; get original A=character to insert
    JSR StaPrintBufferWritePtr
    JSR AdvancePrintBufferWritePtr
    JSR DecrementPrintBufferFree
    ; Return to caller with carry clear to indicate insertion succeeded.
    TSX:LDA VectorEntryStackedFlags+1,X:AND_NOT flagC:STA VectorEntryStackedFlags+1,X
    JMP RestoreRamselClearPrvenReturnFromVectorHandler
}

.RemvHandler
{
IF IBOS_VERSION < 127
    TSX:LDA VectorEntryStackedX,X ; get original X=buffernumber
    CMP #bufNumPrinter:BEQ IsPrinterBuffer
    LDA #ibosREMVIndex:JMP forwardToParentVectorTblEntry
			
.IsPrinterBuffer
ELSE
    LDY #ibosREMVIndex:JSR BufferVHandlerCommon
ENDIF
    PRVS81EN
    PHA
    TSX
    JSR CheckPrintBufferEmpty:BCC PrintBufferNotEmpty
    ; SQUASH: Some similarity with InsvHandler here, could we factor out common code?
    LDA VectorEntryStackedFlags+1,X:ORA #flagC:STA VectorEntryStackedFlags+1,X
IF IBOS_VERSION < 127
    JMP RestoreRamselClearPrvenReturnFromVectorHandler
ELSE
    BNE RestoreRamselClearPrvenReturnFromVectorHandler ; always branch
ENDIF

; IBOS versions before 1.23 return the character in Y for examine and A for remove, which is
; the wrong way round. This works in practice for the all-important case of the OS removing
; characters from the printer buffer to send to the printer because OS 1.20 expects the
; character to be in A for remove. See
; https://stardot.org.uk/forums/viewtopic.php?f=54&p=319880 for discussion on this.
;
; The pre-1.23 behaviour did cause some problems in practice, as discussed here:
; https://stardot.org.uk/forums/viewtopic.php?f=3&t=22868&start=990
; 1.23+ returns the character in A and Y for both examine and remove to be safe.

.PrintBufferNotEmpty
    LDA VectorEntryStackedFlags+1,X:AND_NOT flagC:STA VectorEntryStackedFlags+1,X
    JSR LdaPrintBufferReadPtr
    TSX
    PHA ; note this doesn't affect X so our stack,X references stay the same
    LDA VectorEntryStackedFlags+1,X:AND #flagV:BNE ExamineBuffer
    ; V was cleared by the caller, so we're removing a character from the buffer.
    PLA:STA VectorEntryStackedA+1,X ; overwrite stacked A with character read from our buffer
IF IBOS_VERSION >= 123
    STA VectorEntryStackedY+1,X ; overwrite stacked Y with character read from our buffer
ENDIF
    JSR AdvancePrintBufferReadPtr
    JSR IncrementPrintBufferFree
    JMP RestoreRamselClearPrvenReturnFromVectorHandler

.ExamineBuffer
    ; V was set by the caller, so we're just examining the buffer without removing anything.
    PLA:STA VectorEntryStackedY+1,X ; overwrite stacked Y with character peeked from our buffer
IF IBOS_VERSION >= 123
    STA VectorEntryStackedA+1,X ; overwrite stacked A with character peeked from our buffer
ENDIF
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
IF IBOS_VERSION < 127
    TSX:LDA VectorEntryStackedX,X ; get original X=buffer number
    CMP #bufNumPrinter:BEQ IsPrinterBuffer
    LDA #ibosCNPVIndex:JMP forwardToParentVectorTblEntry

.IsPrinterBuffer
ELSE
    LDY #ibosCNPVIndex:JSR BufferVHandlerCommon
ENDIF
    LDA ramselCopy:PHA
    PRVEN
    TSX:LDA VectorEntryStackedFlags+1,X:AND #flagV:BEQ Count
    ; We're purging the buffer.
    LDX #prvPrintBufferPurgeOption - prv83:JSR ReadPrivateRam8300X:BEQ PurgeOff
    JSR PurgePrintBuffer
.PurgeOff
    JMP RestoreRamselClearPrvenReturnFromVectorHandler

.Count
    LDA VectorEntryStackedFlags+1,X:AND #flagC:BNE CountSpaceLeft
    ; We're counting the entries in the buffer; return them as 16-bit value YX.
    JSR GetPrintBufferUsed
.Common
    TXA:TSX:STA VectorEntryStackedX+1,X ; overwrite stacked X, so we return A to caller in X
    TYA:STA VectorEntryStackedY+1,X ; overwrite stacked Y, so we return A to caller in Y
    JMP RestoreRamselClearPrvenReturnFromVectorHandler

.CountSpaceLeft
    ; We're counting the space left in the buffer; return that as 16-bit value YX.
    JSR GetPrintBufferFree
IF IBOS_VERSION < 127
    TXA:TSX:STA VectorEntryStackedX+1,X ; overwrite stacked X, so we return A to caller in X
    TYA:STA VectorEntryStackedY+1,X ; overwrite stacked Y, so we return A to caller in Y
    JMP RestoreRamselClearPrvenReturnFromVectorHandler
ELSE
    JMP Common
ENDIF
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
IF IBOS_VERSION < 127
    STA prvPrintBufferBankCount
ENDIF
    ; SFTODO: Following code is similar to chunk just below InitialiseBuffer, could
    ; it be factored out?
    JSR SanitisePrvPrintBufferStart:STA prvPrintBufferBankStart
    LDA #&B0:STA prvPrintBufferBankEnd ; SFTODO: Magic constant ("top of private RAM")
    SEC:LDA prvPrintBufferBankEnd:SBC prvPrintBufferBankStart:STA prvPrintBufferSizeMid
IF IBOS_VERSION < 127
    LDA romselCopy:ORA #romselPrvEn:STA prvPrintBufferBankList
    LDA #&FF
    STA prvPrintBufferBankList + 1
    STA prvPrintBufferBankList + 2
    STA prvPrintBufferBankList + 3
ELSE
    JSR SetPrintBufferBanksToPrivateRam
ENDIF
.SoftReset
    JSR PurgePrintBuffer
    PRVDIS
    ; Copy the rom access subroutine used by the printer buffer from ROM into RAM.
    LDY #RomAccessSubroutineTemplateEnd - RomAccessSubroutineTemplate - 1
.SubroutineCopyLoop
    LDA RomAccessSubroutineTemplate,Y:STA RomAccessSubroutine,Y
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
IF IBOS_VERSION < 127
    LDA #0:STA prvPrintBufferPtrBase,X ; redundant, as we did INC this:BNE Rts above
ENDIF
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
IF IBOS_VERSION >= 127
.ClcRts
ENDIF
    CLC
    RTS
IF IBOS_VERSION < 127
.SecRts
    SEC
    RTS
ENDIF

; Return with carry set if and only if the printer buffer is empty.
; SQUASH: This has only one caller
.^CheckPrintBufferEmpty
    XASSERT_USE_PRV1
    LDA prvPrintBufferFreeLow:CMP prvPrintBufferSizeLow:BNE ClcRts
    LDA prvPrintBufferFreeMid:CMP prvPrintBufferSizeMid:BNE ClcRts
    ; ENHANCE: Next line is a duplicate of previous one, it should be checking High not Mid.
    LDA prvPrintBufferFreeMid:CMP prvPrintBufferSizeMid:BNE ClcRts
IF IBOS_VERSION >= 127
.SecRts
ENDIF
    SEC
    RTS
IF IBOS_VERSION < 127
.ClcRts
    CLC
    RTS
ENDIF
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
; Subtract 1 from the 24-bit value in prvPrintBuffer{High,Mid,Low}.
.DecrementPrintBufferFree
    XASSERT_USE_PRV1
IF IBOS_VERSION < 127
    SEC
    LDA prvPrintBufferFreeLow:SBC #1:STA prvPrintBufferFreeLow
    LDA prvPrintBufferFreeMid:SBC #0:STA prvPrintBufferFreeMid
    DECCC prvPrintBufferFreeHigh
ELSE
    ; This is a 24-bit extension of the 16-bit decrement described at
    ; http://6502.org/users/obelisk/6502/algorithms.html.
    LDA prvPrintBufferFreeLow:BNE SkipMidHighDec
    LDA prvPrintBufferFreeMid:BNE SkipHighDec
    DEC prvPrintBufferFreeHigh
.SkipHighDec
    DEC prvPrintBufferFreeMid
.SkipMidHighDec
    DEC prvPrintBufferFreeLow
ENDIF
    RTS

; A code template copied to RAM at RomAccessSubroutine which is patched at runtime to
; read, write or compare A against a byte of sideways ROM in bank Y. X is corrupted.
; SFTODO: Both here (now done) and with the vector RAM stub, it might be better to use a
; naming convention where the ROM copy is suffixed "Template" and the RAM copy doesn't
; have any special naming. The current naming convention isn't that bad, but when it's
; natural for the name of this subroutine to include "Rom" it gets a little confusing.
.RomAccessSubroutineTemplate
    ORG RomAccessSubroutine

    LDX romselCopy
    STY romselCopy
    STY romsel
.RomAccessSubroutineVariableInsn
    EQUB $00, $00, $80 ; <abs instruction> &8000; patched at runtime when copied into RAM
IF IBOS_VERSION < 127
    STX romselCopy:STX romsel
    RTS
ELSE
    JMP osStxRomselAndCopyAndRts
ENDIF

    RELOCATE RomAccessSubroutine, RomAccessSubroutineTemplate
.RomAccessSubroutineTemplateEnd
    ASSERT P% - RomAccessSubroutineTemplate <= RomAccessSubroutineMaxSize

{
; Temporarily page in ROM bank prvPrintBufferBankList[prvPrintBufferReadBankIndex] and do LDA (prvPrintBufferReadPtr)
.^LdaPrintBufferReadPtr
    PHA
    LDX #prvPrintBufferReadPtrIndex
    LDA #opcodeLdaAbs:BNE Common ; always branch

; Temporarily page in ROM bank prvPrintBufferBankList[prvPrintBufferWriteBankIndex] and do STA (prvPrintBufferWritePtr)
.^StaPrintBufferWritePtr
    PHA
    LDX #prvPrintBufferWritePtrIndex
    LDA #opcodeStaAbs
.Common
    XASSERT_USE_PRV1
    STA RomAccessSubroutineVariableInsn
    LDA prvPrintBufferPtrBase    ,X:STA RomAccessSubroutineVariableInsn + 1
    LDA prvPrintBufferPtrBase + 1,X:STA RomAccessSubroutineVariableInsn + 2
    LDY prvPrintBufferPtrBase + 2,X:LDA prvPrintBufferBankList,Y:TAY
    PLA
    JMP RomAccessSubroutine
}

.PurgePrintBuffer
    XASSERT_USE_PRV1
    LDA #0:STA prvPrintBufferWritePtr:STA prvPrintBufferReadPtr
    LDA prvPrintBufferBankStart:STA prvPrintBufferWritePtr + 1:STA prvPrintBufferReadPtr + 1
    LDA prvPrintBufferFirstBankIndex:STA prvPrintBufferWriteBankIndex:STA prvPrintBufferReadBankIndex
    LDA prvPrintBufferSizeLow:STA prvPrintBufferFreeLow
    LDA prvPrintBufferSizeMid:STA prvPrintBufferFreeMid
    LDA prvPrintBufferSizeHigh:STA prvPrintBufferFreeHigh
.LdaPrintBufferReadPtrRts
    RTS

; If prvPrvPrintBufferStart isn't in the range &90-&AC, set it to &AC. We return with prvPrvPrintBufferStart in A.
.SanitisePrvPrintBufferStart
{
MaxPrintBufferStart = prv8End - 1024 ; print buffer must be at least 1K

    LDX #prvPrvPrintBufferStart - prv83:JSR ReadPrivateRam8300X
    CMP #hi(prv8Start):BCC UseAC
IF IBOS_VERSION < 127
    CMP #hi(MaxPrintBufferStart):BCC Rts
.UseAC
    LDA #hi(MaxPrintBufferStart):JSR WritePrivateRam8300X
.Rts
    RTS
ELSE
    CMP #hi(MaxPrintBufferStart):BCC LdaPrintBufferReadPtrRts
.UseAC
    LDA #hi(MaxPrintBufferStart):JMP WritePrivateRam8300X
ENDIF
}

IF IBOS_VERSION < 127
    PRINT end - P%, "bytes free"
ELSE
.code_end
    ; Add a pointer to the full reset data table in a known place at the end of the IBOS ROM,
    ; so it can potentially be used by the recovery tool to ensure consistency. We only do the
    ; SKIPTO if it will succeed; we'll still hit the guard if the ROM is over-full without the
    ; SKIPTO, but it means we get the negative bytes free reported correctly when the guard is
    ; disabled instead of the SKIPTO terminating the build.
    IF P% <= &BFFE
        SKIPTO &BFFE
    ENDIF
    EQUW FullResetPrvTemplate+UserRegDefaultTable-FullResetPrvCopy
    PRINT (end - code_end) - 2, "bytes free"
ENDIF

IF IBOS_VERSION == 120
IF IBOS120_VARIANT == 0
    SAVE "IBOS-120.rom", start, end
ELSE
    SAVE "IBOS-120-b-em.rom", start, end
ENDIF
ELIF IBOS_VERSION == 121
    SAVE "IBOS-121.rom", start, end
ELIF IBOS_VERSION == 122
    SAVE "IBOS-122.rom", start, end
ELIF IBOS_VERSION == 123
    SAVE "IBOS-123.rom", start, end
ELIF IBOS_VERSION == 124
    SAVE "IBOS-124.rom", start, end
ELIF IBOS_VERSION == 125
    SAVE "IBOS-125.rom", start, end
ELIF IBOS_VERSION == 126
    SAVE "IBOS-126.rom", start, end
ELIF IBOS_VERSION == 127
    SAVE "IBOS-127.rom", start, end
ELSE
    ERROR "Unknown IBOS_VERSION"
ENDIF

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
; but OS 1.20 interprets this as an abbreviation for "*CODE" and IBOS never gets a chance to
; see it. Short of installing a USERV handler, there isn't much we can do about this.

; SFTODO: Look at the integrap ROM packaged with b-em and see if we can build that too.

; SFTODO: If a user application is using the private RAM (except the 1K allocated to IBOS), is
; there a danger that things like pressing Escape will trigger the printer buffer to be flushed
; and corrupt data in the private RAM? Or will this leave the "other" 11K of the private RAM
; alone as long as there's no data in the buffer? I am assuming the printer buffer is the only
; thing in IBOS that uses the "other" 11K, but if anything else does that might be a concern
; too. *If necessary*, it might be nice to provide some kind of call (OSWORD/OSBYTE) which a
; user application can use to tell IBOS "I want the other 11K, keep your hands off it". There
; is a bit of a corner case here as IBOS steals the OS printer buffer, which is OK as long as
; it is providing its own printer buffer (at the moment you cannot turn it off), but this means
; you cannot currently use the 11K private RAM for yourself *and* print. Maybe this is OK, but
; ideally it would be possible to do both (but not with a big buffer, of course). (We could say
; "allocate a SWR bank for the buffer if you're using the 11K and want to print", but in that
; case the application might just as well use the SWR bank itself and leave the private RAM to
; IBOS.) Maybe an application using the 11K should be expected to do *FX5,0 first???

;; Local Variables:
;; fill-column: 95
;; End:
