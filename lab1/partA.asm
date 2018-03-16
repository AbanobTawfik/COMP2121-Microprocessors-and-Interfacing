	ldi r16, low(640)
	ldi r17, high(640)
	ldi r18, low(511)
	ldi r19, high(511)
	
	mov r21, r16
	add r21, r18
	mov r20, r17
	adc r20, r19
	


halt:
	rjmp halt
;remember we add our carry to the LOWER BITS WHICH ARE OUR FRONT BITS EG. 0x(04)7f -> LOWER BITS R 04
need to check system mantisa to workout which way bits are written
	
