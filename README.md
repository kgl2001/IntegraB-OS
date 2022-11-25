# Integra-B OS (IBOS)

## Table of contents
- [Overview](#overview)
- [Changelog](#changelog)
- [Building](#building)

## Overview

This repository holds source code for the IBOS ROM used with the Integra-B expansion for the BBC Micro. It is based on a disassembly of the last official release by Computech (1.20) and can rebuild that version as well as newer versions containing bug fixes and enhancements.

## Building

You will need a copy of [beebasm](https://github.com/stardot/beebasm) 1.09 or later in order to build the sources. Each version has a separate toplevel file, e.g. [IBOS-120.asm] for v1.20. To build any particular version, execute beebasm using a command like:
```
beebasm -w -i IBOS-120.asm
```
This will create an IBOS-120.rom file, which is the IBOS ROM image.

All the top level files simply define some constants and include the main source file [IBOS.asm].

There is a [Makefile] which will build all the versions and verify their md5sum to check they have built correctly. It will also create tags files suitable for use with vim or emacs to help with navigating the source.

## Changelog

* v1.20 (1989):
  * Last official release by Computech.

* v1.20-b-em:
  * Patched version of v1.20 distributed with the [b-em](https://github.com/stardot/b-em) BBC Micro emulator.
  * userRegFdriveCaps is &20 instead of &23
  * userRegDiscNetBootData is &A1 instead of &A0
  * userRegCentury is 20 instead of 19
  * default day of week on reset is Saturday 1/1/2000 instead of Monday 1/1/1900

* v1.21 (2019):
  * Copyright string changed from "Computech" to "BBC Micro"
  * Full reset of CMOS RAM sets default LANG to &E and FILE to &C; previously these were both defaulted to the bank containing IBOS (typically &F).
  * userRegModeShadowTV defaults to &E7 instead of &17
  * userRegFdriveCaps defaults to &20 (as in v1.20-b-em, but a change from v1.20).
  * userRegDiscNetBootData defaults to &A1 (as in v1.20, but a change from v1.20-b-em).
  * userRegCentury defaults to 20 (as in v1.20-b-em, but a change from v1.20)

* v1.22 (2021):
  * Fix ANFS 4.18 incompatibility, notably a lock up caused by ANFS 4.18 re-issuing service call 1 during reset.

* v1.23 (2022):
  * TODO BUG WITH BUFFER EXAMINE

* v1.24 (2022):
  * Full reset of CMOS RAM sets default LANG and FILE to the bank containing IBOS (typically &F), reverting the change in v1.21.
  * TODO *FX5/PRINTER SELECT CHANGE

* v1.26 (2022):
  * OSWORD &0F (write real time clock) implemented.
  * *DATE= accepts spaces as well as slashes to separate date components.
  * *DATE= accepts three-letter English month abbreviations as well as numeric months.
