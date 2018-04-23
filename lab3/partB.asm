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
.equ pattern = 0b111111110000000
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
	;now we want to set our port C as output (all leds as output)
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
	;then we want to do a ROL - rotate left through carry on the lower register
	;now we check if the carry flag has been set from our first lsl call
	;if it has that means we now need to adjust our pattern (create a wrapper)
	;if it has we want to manually load that carry flag into the last bit of the upper part of the string
	;to do that we manually load and store bit using bld and bst
	lds r24, patternState
	lsl r24 
	;store updated pattern which was logically left shifted by 1
	sts patternState, r24
	;now we want to logically shift the second part of the pattern to the left aswell but we rotate it to the left
	lds r24, patternState + 1;
	rol r24
	sts patternState + 1, r24
	;if there is a carry the 7th bit (aka last bit) will be missing so we 
	;manually set the bit that carries over upon the lsl and set it in the last bit for the 
	;high bits
	brcs fixPattern
	;otherwise just print the pattern
	jmp printPattern
	
printPattern:
;load the pattern into the leds
	lds leds, patternState
;output the pattern to portC as required
	out PORTC, leds
;clear the temp counter as a second has passed
	clear tempCounter
;we want to now update our seconds counter
;load into the register pair r24:r25 the secondCounter
	lds r24, secondCounter
	lds r25, secondCounter + 1
;add 1 to the counter
	adiw r25:r24, 1
;to avoid any overwriting issues 
	clear secondCounter
;store the updated counter back into memory
	sts secondCounter, r24
	sts secondCounter + 1, r25
;jump to end
	rjmp endIF


fixPattern:	
	lds r24, patternState
	;load 1 into r16
	ldi r16, 1
	;set the 0th bit aka 1 into the T flag as 1 -> 0000 0001<----- 0th bit 
	bst r16, 0
	;now we want to load into the 7th bit of our rotated byte the T flag aka 1
	bld r24, 0
	;store the updated byte
	sts patternState, r24
	jmp printPattern


NotSecond:
	sts TempCounter, r24		;update the value of the temporary counter
	sts TempCounter+1, r25	
	jmp EndIf

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
	ldi r16, high(pattern)
	sts patternState, r16
	ldi r16, low(pattern)
	sts patternState + 1, r16

	lds leds, patternState
	out PORTC, leds			;will print the higher bits of the pattern, can do +1 to do other way around
	clear tempCounter
	clear secondCounter


	ldi temp, 0b00000010
	out TCCR0B, temp				; prescalining = 8
	ldi temp, 1<<TOIE0				; 128 microseconds
	sts TIMSK0, temp				; T/C0 interrupt enable
	sei


loop: rjmp loop ; loop 
