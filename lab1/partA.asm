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

	
