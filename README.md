# Integra-B OS (IBOS)

## Table of contents
- [Overview](#overview)
- [Building](#building)
- [Getting help](#getting-help)
- [Changelog](#changelog)

## Overview

This repository holds source code for the IBOS ROM used with the Integra-B expansion for the BBC Micro. It is based on a disassembly of the last official release by Computech (1.20) and can rebuild that version as well as newer versions containing bug fixes and enhancements.

## Building

You will need a copy of [beebasm](https://github.com/stardot/beebasm) 1.09 or later in order to build the sources. Each version has a separate top level file, e.g. [IBOS-120.asm](IBOS-120.asm) for v1.20. To build any particular version, execute beebasm using a command like:
```
beebasm -w -i IBOS-120.asm
```
This will create an IBOS-120.rom file, which is the IBOS ROM image. The `-w` option is important as the source code uses macro names which start with 6502 mnemonics and these will not assemble correctly otherwise.

All the top level files simply define some constants and include the main source file [IBOS.asm](IBOS.asm).

There is a [Makefile](Makefile) which will build all the versions and verify their md5sums to check they have built correctly. It will also create tags files suitable for use with vim or emacs to help with navigating the source.

## Getting help

If you have problems or suggestions for improvement, please post in the [IBOS thread](https://stardot.org.uk/forums/viewtopic.php?f=2&t=25898) on the [stardot](https://stardot.org.uk) forums. This is preferred to raising issues in github, but if you want to browse or submit a github issue, please make sure you are using the main repo [here](https://github.com/kgl2001/IntegraB-OS/issues).

## Changelog

* v1.20 (1989):
  * Last official release by Computech.

* v1.20-em:
  * This is a patched version of v1.20 distributed with the [b-em](https://github.com/stardot/b-em) and [BeebEm](https://github.com/stardot/beebem-windows) BBC Micro emulators. It identifies itself as v1.20 so can only be distinguished by its filename within the emulator installation (integra12p.rom in b-em, IBOS12P.ROM in BeebEm), examining the ROM or checking for the following changes.
  * Set current date to Saturday 1st January 2000 on full reset; previously the date was set to Monday 1st January 1900.
  * Set configured FDRIVE to 0 on full reset; previously this was set to 3.
  * On full reset, set DFS as the default filing system when DNFS is the configured default filing system ROM; previously this was set to NFS.

* v1.21 (2019):
  * (These changes are described as if v1.20-em is the previous version.)
  * Copyright string and startup banner text changed from "Computech" to "BBC Micro"
  * Set configured LANG to &E and FILE to &C on full reset; previously these were both defaulted to the bank containing IBOS (typically &F).
  * Set configured TV to 255,0 on full reset; previously this was set to 0,1.

* v1.22 (2021):
  * Fix lock up with ANFS 4.18. This was a result of ANFS 4.18 re-issuing service call 1 during reset, which caused IBOS to claim vectors twice and end up in an infinite loop as a result.

* v1.23 (April 2022):
  * Make IBOS's REMV handler return the character in both A and Y when operating on the printer buffer whether the caller is trying to examine or remove characters. This fixes problems when printing to a network printer. Earlier versions returned the character in Y for examine calls and in A for remove calls, which is the wrong way round but conveniently works correctly most of the time due to quirks in OS 1.20. Returning the character in both registers all the time is safe and maximally compatible.

* v1.24 (August 2022):
  * Set configured LANG and FILE to the bank containing IBOS (typically &F) on full reset, reverting the change in v1.21.
  * Apply the configured PRINTER option later during the reset (break) sequence; this fixes problems when the configured PRINTER option is a network printer.

* v1.25 (November 2022):
  * Include the command argument specification in the error message generated when a * command's arguments are incorrect. Earlier versions behaved inconsistently and sometimes did this and sometimes didn't.
  * Don't beep when parsing an integer from the command line fails.

* v1.26 (November 2022):
  * Support OSWORD &0F (write real time clock).
  * Accept spaces as well as slashes to separate date components in *DATE= arguments.
  * Accept three letter English month abbreviations as well as numeric months in *DATE= arguments.
  * Set configured TV to 0,1 on full reset, reverting the change in v1.21.
  * Allow *CONFIGURE LANG to optionally take two ROM banks, the first being the ROM bank to enter as a language when no tube is active, the second being the ROM bank to enter as a language when the tube is active. If a single argument is specified, this is used regardless of tube presence or absence, as before.
  * When no tube is active, check before entering the *CONFIGURE-d language that it is not a HI language (i.e. its relocation address, if any, is &8000) and enter the IBOS No Language Environment instead if it is. This avoids hanging if (for example) the *CONFIGURE-d language is HIBASIC and there is no second processor.
  * Re-arrange battery-backed RAM storage of *CONFIGURE FILE and *CONFIGURE LANG to accommodate having two separate languages configured for tube/non-tube, as described above. This will mean users need to issue *CONFIGURE FILE and *CONFIGURE LANG commands after upgrading, and *CSAVE-d configurations from earlier IBOS versions will be incompatible with IBOS 1.26 and newer. A valid language (probably the IBOS No Language Environment, which allows * commands to be entered) should still be entered after upgrading without the need for a full reset.
  * Default LANG (both tube and non-tube) and FILE to &F on full reset. This will typically be the bank containing IBOS, but the other changes in this version mean that even if it isn't, a language will still be entered successfully.
