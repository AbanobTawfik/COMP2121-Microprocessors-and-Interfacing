; Part C – Calculator (4 Marks)
; Use the keypad and LCD together to implement a simple unsigned 8-bit calculator. The program
; should allow the user to enter decimal numbers using the number keys on the keypad. Numbers
; should be displayed on the bottom row of the LCD as they are entered. You do not need to handle
; overflow.
; The calculator should use an accumulator that is initialised to 0 when the program starts. Pressing
; the ‘*’ button should reset the accumulator to 0 and clear the current input. The current
; accumulator should be displayed on the top line of the LCD at all times.
; After a number has been entered, the buttons ‘A’ and ‘B’ are used to add or subtract the new
; number from the accumulator.
; Each key press must be registered only once, and holding down a key should not result in multiple
; inputs. This will require some form of debouncing.

.include "m2560def.inc"


.macro clear
	ldi YL, low(@0)	
	ldi YH, high(@0)
	clr temp1
	st Y+, temp1		;we clear the two bytes located where the label @a0 is by loading in a clear byte
	st Y, temp1
.endmacro

.def temp1 = r16

.dseg
	secondCounter:			;3 flashes 1s each so when this second counter is 3 we reset, and overwrite pattern with new 1
		.byte 2
	tempCounter:			;used to check if a second has passed
		.byte 2
	voltage:
		.byte 2
.cseg

.org 0
	jmp RESET

RESET:
	ldi r16, low(RAMEND)
	out SPL, r16
	ldi r16, high(RAMEND)
	out SPH, r16
	;this is PE2 because from some reason its PE4???????????????????????????
	ldi temp1, 0b00010000
	;we only want to output the red LED ontop
	out DDRE, temp1
	;show the red LED
	ldi temp1, 0xFF
	out portE, temp1
	out DDRC, temp1
	; the voltage display initially starts at max
	sts low(voltage), temp1
	sts high(voltage), temp1
	;initialise voltage to max
	sts OCR3BL, temp1
	sts OCR3BH, temp1
	ldi temp1, (1 << CS30) 		; set the Timer3 to Phase Correct PWM mode. 
	sts TCCR3B, temp1
	ldi temp1, (1<< WGM30)|(1<<COM3B1)
	sts TCCR3A, temp1



	
loopA:
	;load the word pair from memory
	lds XL, low(voltage)
	lds XH, high(voltage)
	;subtract 1 from the word pair
	sbiw XL:XH, 1
	;store the updated pair into memory and store the decremented voltage to dim the lights
	sts low(voltage), XL
	sts high(voltage), XH
	sts OCR3BL, XL
	sts OCR3BH, XH
	;3ms sleep is perfect for flashing on/off every 1s
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	;when the word pair reaches 0 we want to reload (reset voltage to max)
	cpi XL, 0
	cpi XH, 0
	brne loopA

loopB:
	;reset and store the voltage
	ldi temp1, 0xFF
	sts low(voltage), temp1
	sts high(voltage), temp1
	jmp loopA 

	
.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead

sleep_1ms:
	push r24
	push r25
	ldi r25, high(DELAY_1MS)
	ldi r24, low(DELAY_1MS)
delayloop_1ms:
	sbiw r25:r24, 1
	brne delayloop_1ms
	pop r25
	pop r24
	ret

