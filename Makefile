all: IBOS-01.rom

IBOS-01.rom: IBOS.asm Makefile
	python beebasm-tags.py IBOS.asm
	python beebasm-tags.py -e IBOS.asm
	beebasm -v -i IBOS.asm > IBOS-01.lst
	@# We rename the output if it's not identical so that doing a subsequent
	@# make doesn't (correctly, but unhelpfully) say there's nothing to do.
	@cmp IBOS-01.rom IBOS-Orig.rom || (echo "New ROM is not identical to original"; mv IBOS-01.rom IBOS-01-variant.rom; exit 1)

clean:
	/bin/rm -f IBOS.lst IBOS-01.rom IBOS-01-variant.rom
