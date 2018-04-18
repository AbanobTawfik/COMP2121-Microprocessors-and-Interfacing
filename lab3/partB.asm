;
; AssemblerApplication7.asm
;
; Created: 18/04/2018 4:29:07 PM
; Author : Abs Tawfik
;
;making a sliding LED pattern 
;timer0 will create an interrupt that lasts for 1 real time second
;afterwards the pattern will shit to the left (or right) by 1 
;1 pattern-cycle takes 16 seconds since 16 bit pattern 

; Replace with your application code
.include "m2560def.inc"
;simulate the an on off pattern, which this code should appear lights r shifting to the right or left
.equ pattern = 0b1010101010101010
.def temp = r16
.def leds = r17

;this will clear a word in memory at the address the label was located
.macro clear
	ldi YL, low(@0)	
	ldi YH, high(@0)
	clr temp
	st Y+, temp		;we clear the two bytes located where the label @a0 is by loading in a clear byte
	st Y, temp
.endmacro

.dseg 
secondCounter:			;will be used to store time counted 
	.byte 2
tempCounter:			;will be used to check if 1s has passed
	.byte 2
patternState:
	.byte 2				;16 bit pattern we want to check state of 

.cseg
.org 0x0000
	jmp RESET
	jmp DEFAULT			;if the IRQ0 (interrupt request 0 is not handled) go to default
	jmp DEFAULT			;if the IRQ1 (interrupt rquest 1 is not handled) go to default
.org OVF0addr
	jmp Timer0OVF		;jump to the handler for timer0 overflowing

jmp DEFAULT             ;the default for every other interrupt

DEFAULT: 
	reti

RESET:
	;initalising stack
	ldi temp, high(RAMEND)
	out SPH, temp
	ldi temp, low(RAMEND)
	out SPL, temp
	;now we want to set our port C as output (all pins)
	ser temp
	out DDRC, temp
	rjmp main

Timer0OVF:
;storing onto the stack the values we want to preserve and conflict registers
;  PROLOGUE
	in temp, SREG
	push temp
	push YH
	push YL
	push r25
	push r24

	;now we want to load the value of temporary counter into the register pair r25/r24
	lds r24, tempCounter
	lds r25, tempCounter+1
	adiw r25:r24, 1			;increment the register pair

	cpi r24, low(7812)		;check if the register pair (r25:r24) = 7812
	ldi temp, high(7812)
	cpc r25, temp
	brne NotSecond			;if the register pair are not 7812, a second hasnt passed so we jump to NotSecond which will increase counter by 1
	;if this condition has not been met then we will update our pattern by shifting it by 1 to left?
	;shifting our 16 bit pattern to the left has two steps
	;first as quoted from an AVRFREAKS post forum on shifting 16 bit numbers, we want to perform a lsl on the upper regster
	;then we want to do a ROL - rotate left through carry on the lower register, this will take the carry and put it 
	;in the bit 7 of the lower 8 bits, this will be wrapped itself this way as the carry is in bit 7 (last bit of the lower bits)
	;here we are multiplying number by 2 to left shift by the way, 
	lds r24, patternState
	lsl r24 
	;store updated pattern which was logically left shifted by 1
	sts patternState, r24
	;now we want to logically shift the second part of the pattern to the left aswell but we rotate it to the left
	lds r24, patternState + 1;
	rol r24
	sts patternState + 1, r24
	;if there is no carry we want to just print out LED state
	jmp printPattern

printPattern:
	lds leds, patternState
	out PORTC, leds


	sts secondCounter, r24
	sts secondCounter+1, r25
	rjmp endIF

NotSecond:
	sts TempCounter, r24		;update the value of the temporary counter
	sts TempCounter+1, r25	

EndIf:
	;epilogue
	pop r24
	pop r25
	pop YL
	pop YH
	pop temp
	;restore our SREG especially xD
	out SREG, temp
	reti	

main:
;we want to load our pattern into the data memory 
	ldi r16, low(pattern)
	sts patternState, r16
	ldi r17, high(pattern)
	sts patternState + 1, r16

	lds leds, patternState
	out PORTC, leds			;will print the higher bits of the pattern, can do +1 to do other way around
	clear tempCounter
	clear secondCounter

	ldi temp, 0b00000000
	out TCCR0A, temp
	ldi temp, 0b00000010
	out TCCR0B, temp				; prescalining = 8
	ldi temp, 1<<TOIE0				; 128 microseconds
	sts TIMSK0, temp				; T/C0 interrupt enable
	sei								;enable gloable interrupt
	
loop: rjmp loop ; loop till mainual stop




