all: IBOS-120.rom IBOS-121.rom tags TAGS

IBOS-120.rom tags TAGS: IBOS-120.asm Makefile
	python beebasm-tags.py IBOS-120.asm
	python beebasm-tags.py -e IBOS-120.asm
	beebasm -w -v -i IBOS-120.asm > IBOS-120.lst
	@# We rename the output if it's not identical so that doing a subsequent
	@# make doesn't (correctly, but unhelpfully) say there's nothing to do.
	@cmp IBOS-120.rom IBOS-120-Orig.rom || (echo "New IBOS 1.20 ROM is not identical to original"; mv IBOS-120.rom IBOS-120-variant.rom; exit 1)

IBOS-121.rom tags TAGS: IBOS-121.asm Makefile
	python beebasm-tags.py IBOS-121.asm
	python beebasm-tags.py -e IBOS-121.asm
	beebasm -w -v -i IBOS-121.asm > IBOS-121.lst
	@# We rename the output if it's not identical so that doing a subsequent
	@# make doesn't (correctly, but unhelpfully) say there's nothing to do.
	@cmp IBOS-121.rom IBOS-121-Orig.rom || (echo "New IBOS 1.21 ROM is not identical to original"; mv IBOS-121.rom IBOS-121-variant.rom; exit 1)

clean:
	/bin/rm -f IBOS-120.lst IBOS-120.rom IBOS-120-variant.rom IBOS-121.lst IBOS-121.rom IBOS-121-variant.rom tags TAGS
