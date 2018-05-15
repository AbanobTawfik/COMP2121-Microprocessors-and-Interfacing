/*
 * macros.asm
 *
 *  Created: 15/05/2018 4:20:49 PM
 *   Author: Abs Tawfik
 */ 

.macro prologue
	in r16, SREG
	push r16
	push r17
	push r18
	push r19
	push r20
	push r21
	push r22
	push r23
	push r24
	push r25
	push XL
	push XH
	push YL
	push YH
	push ZL
	push ZH
.endmacro

.macro epilogue
	pop ZH
	pop ZL
	pop YH
	pop YL
	pop XH
	pop XL
	pop r25
	pop r24
	pop r23
	pop r22
	pop r21
	pop r20
	pop r19
	pop r18
	pop r17
	pop r16
	out SREG, r16
.endmacro

.macro clear
	ldi YL, low(@0)	
	ldi YH, high(@0)
	clr temp
	st Y+, temp		;we clear the two bytes located where the label @a0 is by loading in a clear byte
	st Y, temp

.endmacro