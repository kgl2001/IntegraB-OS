all: IBOS-120.rom IBOS-120-b-em.rom IBOS-121.rom IBOS-122.rom IBOS-123.rom tags TAGS

tags TAGS: IBOS.asm
	python beebasm-tags.py IBOS.asm
	python beebasm-tags.py -e IBOS.asm

IBOS-120.rom: IBOS-120.asm IBOS.asm Makefile
	beebasm -w -v -i IBOS-120.asm > IBOS-120.lst
	@# We rename the output if it's not identical so that doing a subsequent
	@# make doesn't (correctly, but unhelpfully) say there's nothing to do.
	@cmp IBOS-120.rom IBOS-120-Orig.rom || (echo "New IBOS 1.20 ROM is not identical to original"; mv IBOS-120.rom IBOS-120-variant.rom; exit 1)

IBOS-120-b-em.rom: IBOS-120-b-em.asm IBOS.asm Makefile
	beebasm -w -v -i IBOS-120-b-em.asm > IBOS-120-b-em.lst
	@# We rename the output if it's not identical so that doing a subsequent
	@# make doesn't (correctly, but unhelpfully) say there's nothing to do.
	@cmp IBOS-120-b-em.rom IBOS-120-b-em-Orig.rom || (echo "New IBOS 1.20-b-em ROM is not identical to original"; mv IBOS-120-b-em.rom IBOS-120-b-em-variant.rom; exit 1)

IBOS-121.rom: IBOS-121.asm IBOS.asm Makefile
	beebasm -w -v -i IBOS-121.asm > IBOS-121.lst
	@# We rename the output if it's not identical so that doing a subsequent
	@# make doesn't (correctly, but unhelpfully) say there's nothing to do.
	@cmp IBOS-121.rom IBOS-121-Orig.rom || (echo "New IBOS 1.21 ROM is not identical to original"; mv IBOS-121.rom IBOS-121-variant.rom; exit 1)

IBOS-122.rom: IBOS-122.asm IBOS.asm Makefile
	beebasm -w -v -i IBOS-122.asm > IBOS-122.lst
	@# We rename the output if it's not identical so that doing a subsequent
	@# make doesn't (correctly, but unhelpfully) say there's nothing to do.
	@md5sum IBOS-122.rom | grep -q 1bd281c4cad0263b2162984d0becba9e || (echo "New IBOS 1.22 ROM is not identical to original"; mv IBOS-122.rom IBOS-122-variant.rom; exit 1)

IBOS-123.rom: IBOS-123.asm IBOS.asm Makefile
	beebasm -w -v -i IBOS-123.asm > IBOS-123.lst
	@# We rename the output if it's not identical so that doing a subsequent
	@# make doesn't (correctly, but unhelpfully) say there's nothing to do.
	@md5sum IBOS-123.rom | grep -q 9ad2a73e45e3f272f016b25149af31e3 || (echo "New IBOS 1.23 ROM is not identical to original"; mv IBOS-123.rom IBOS-123-variant.rom; exit 1)

clean:
	/bin/rm -f IBOS-120.lst IBOS-120.rom IBOS-120-variant.rom IBOS-120-b-em.lst IBOS-120-b-em.rom IBOS-120-b-em-variant.rom IBOS-121.lst IBOS-121.rom IBOS-121-variant.rom IBOS-122.lst IBOS-122.rom IBOS-123.rom IBOS-123.lst tags TAGS
