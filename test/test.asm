macro testrom id
	org &8000
	clear &8000,&BFFF
	.header
		equb 0, 0, 0
		jmp service_entry
		equb &82
		equb copyright - header
		equb 0
		equs "Test ROM ", 'A'+id, 0
	.copyright
		equs 0, "(C)", 0
	.service_entry
		rts
endmacro

testrom 0
save "ROMA", &8000, P%
testrom 1
save "ROMB", &8000, P%
putbasic "osword43-a.bas", "OSW43A"
putbasic "osword43-b.bas", "OSW43B"
putbasic "osword43-c.bas", "OSW43C"
putbasic "osword43-d.bas", "OSW43D"
putbasic "date.bas", "DATE"
putbasic "oswrsc.bas", "OSWRSC"
putbasic "osword0f-a.bas", "OSW0FA"
