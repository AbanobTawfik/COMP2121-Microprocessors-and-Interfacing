.include "m2560def.inc"
;
; AssemblerApplication1.asm
;
; Created: 11/03/2018 8:34:38 PM
; Author : Abs Tawfik
;
.dseg
retword:
	.byte 20


.cseg
word: .db "thisshudreverse",0

	;loading our word into Z reg from program memory 
    ldi ZL, low(word<<1)
	ldi ZH, high(word<<1)

	;setting up the stack
	ldi XL, low(RAMEND-20)		;20 bytes to store 20 characters in stack
	out SPL, XL					;adjust the stack pointer to point to the top of stack
	ldi XH, high(RAMEND-20)
	out SPH, XH

	ldi YL, low(retword)		;load the address of return array into Y pointer
	ldi YH, high(retword)
	ldi r17, 0			;counter for our word length

puttheword:
	;loop to store the word into memory
	lpm r16, Z+
	cpi r16, 0
	breq reverseString

	;else you want to push onto the stack the character from program memory
	push r16
	;increment our string length to keep track of our string length
	inc r17  
	rjmp puttheword

reverseString:
	
	;pop our letter off stack stack is LIFO so will reverse the input
	pop r16
	dec r17
	st Y+, r16	;store the word in reverse order into our return array (Y pointer points to return array)

	cpi r17, 0
	breq addnullcharacter
	rjmp reverseString

addnullcharacter:
	ldi r16, 0
	st Y+, r16

halt:
	rjmp halt


