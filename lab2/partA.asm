.include "m2560def.inc"
;
; AssemblerApplication1.asm
;
; Created: 11/03/2018 8:34:38 PM
; Author : Abs Tawfik
;
.def stringlength = r17
.def singlecharacter = r16

word: .db "thisshudreverse",0

	;making our X pointer 
    ldi ZL, low(word<<1)
	ldi ZH, high(word<<1)
	;setting up the stack
	ldi r18, low(RAMEND)
	out SPL, r18
	ldi r18, high(RAMEND)
	out SPL, r18

	ldi YL, low(0x200)
	ldi YH, low(0x200)
	ldi stringlength, 0

puttheword:
	;loop to store the word into memory
	lpm singlecharacter, Z+
	cpi singlecharacter, 0
	breq reverseString

	;else you want to push onto the stack
	push singlecharacter
	;increment our string length
	inc stringlength  
	rjmp puttheword

reverseString:
	
	;pop our letter off stack (this is how we reverse Boi
	pop singlecharacter
	dec stringlength
	st Y+, singlecharacter

	cpi stringlength, 0
	breq addnullcharacter
	rjmp reverseString

addnullcharacter:
	ldi singlecharacter, 0
	st Y+, singlecharacter
	ldi YL, low(0x200)
	ldi YH, low(0x200)

printstring:
	ld singlecharacter, Y+
	cpi singlecharacter, 0
	breq halt
	rjmp printstring

halt:
	rjmp halt


