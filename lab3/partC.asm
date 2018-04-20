;Part C – Dynamic Pattern (4 Marks)
;Use the two push buttons to enter a binary pattern, and then display it on the LEDs. The left button
;(PB1) will enter a 1, and the right button (PB0) will enter a 0. When 8 bits have been collected, they
;should be displayed on the green LEDs 3 times, with each flash lasting one second and all LEDs
;turned off for one second after each flash. The bits should be displayed in the order they were
;entered, with the first one on the top LED.
;You must use timer0 to generate an interrupt to control the display speed, and falling-edge external
;interrupts 0 and 1 to detect the button pushes. It must be possible to enter a new pattern while the
;last one is still displaying, although you may assume that no more than one pattern will be entered
;while the last one is displaying.
;The buttons must be software debounced, so that one button press reliably generates only a single
;bit in the pattern. You should implement debouncing by ignoring spurious interrupts, not by
;disabling interrupts or busy-waiting.
;this will clear a word in memory at the address the label was located
.macro clear
	ldi YL, low(@0)	
	ldi YH, high(@0)
	clr temp
	st Y+, temp		;we clear the two bytes located where the label @a0 is by loading in a clear byte
	st Y, temp

.endmacro
.def temp = r16
.def leds = r17
.dseg
patternState:
	.byte 1				;single 8 byte pattern to show
queuedPattern:
	.byte 1				;single 8 byte pattern which is entered while current is displayed
secondCounter:			;3 flashes 1s each so when this second counter is 3 we reset, and overwrite pattern with new 1
	.byte 1
tempCounter:			;used to check if a second has passed
	.byte 1
enableLights:
	.byte 1
debounceTimer:
	.byte 1
numberOfFlashes:
	.byte 1
numberOfBitsInPattern:
	.byte 1
;from table
;PORT D RDX3 INPUTS PB1
;PORT D RDX4 INPUTS PB0
.cseg
.org 0x0000
	jmp RESET
	jmp PB1_ON_PRESS	;IRQ0 will be the interrupt handled by connecting PB1 to the INT0 portD aka RDX3
	jmp PB0_ON_PRESS	;IRQ1 will be the interrupt handled by connecting PB0 to the INT1 portD aka RDX4
	jmp DEFAULT			;other interrupts handled by default reti

.org OVF0addr
	jmp Timer0OVF		;this will be handler for timer overflow

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
	jmp main

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
	;IF A SECOND HAS PASSED
	lds temp, enableLights
	cpi temp, 0x00			;turn off the lights
	breq flashOff
	;otherwise 
	cpi temp, 0xFF			;turn on the lights
	breq flashOn
	;otherwise jmp to epliogue 
	jmp timerEpliogue

flahOff:
	ldi r16, 0xFF
	out DDRc, r16    ;set portC as output
	ldi leds, 0x00   ;set led as off pattern
	out portC, r16
	;set the enable lights to flash on now
	ldi temp, 0xFF
	sts enableLights, temp
	jmp timerEpilogue

flashOn:
	ldi r16, 0xFF
	out DDRc, r16    ;set portC as output
	lds temp, currentPattern
	out portC, temp
	;set the enable lights to flash on now
	ldi temp, 0x00
	sts enableLights, temp
	jmp timerEpilogue

timerEpilogue:
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
	ldi temp, 0b00000000
	out TCCR0A, temp
	ldi temp, 0b00000010
	out TCCR0B, temp				; prescalining = 8
	ldi temp, 1<<TOIE0				; 128 microseconds
	sts TIMSK0, temp				; T/C0 interrupt enable
	sei

loop: rjmp loop ; loop 
