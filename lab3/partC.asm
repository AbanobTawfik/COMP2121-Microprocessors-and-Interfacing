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
nextPattern:
	.byte 1				;single 8 byte pattern which is entered while current is displayed
secondCounter:			;3 flashes 1s each so when this second counter is 3 we reset, and overwrite pattern with new 1
	.byte 2
tempCounter:			;used to check if a second has passed
	.byte 2
enableLights:
	.byte 1
debounceLeftStatus:
	.byte 1
debounceRightStatus:
	.byte 1
debounceTimer:
	.byte 2
numberOfFlashes:
	.byte 1
numberOfBitsInPattern:
	.byte 1
firstPattern:
	.byte 1
patternReady:
	.byte 1
;from table
;PORT D RDX3 INPUTS PB1
;PORT D RDX4 INPUTS PB0
.cseg
.org 0x0000
	jmp RESET
.org INT0addr ; INT0addr is the address of EXT_INT0
	jmp PB0_ON_PRESS
.org INT1addr ; INT1addr is the address of EXT_INT1
	jmp PB1_ON_PRESS	;IRQ0 will be the interrupt handled by connecting PB1 to the INT0 portD aka RDX3

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
	;now for the important part is sent INT1 and INT0 to trigger on falling edges for external interupt
	ldi temp, (1 << ISC11) | (1 << ISC01)
	;set the external interrupt control register A to trigger for INT0 and INT1
	;we chose EICRA because it handles for INT0-INT3
	sts EICRA, temp
	;now we want to enable int0 and int1
	in temp, EIMSK
	ori temp, (1 <<INT0) | (1 << INT1)
	out EIMSK, temp
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
	;button debouncing ~100 ms since 7812 = 1 second, 25 ms = 7812/1000 * 100 
;if the buttons status is on we want to start counter to reset it
	lds temp, debounceRightStatus
	cpi temp, 0
	breq debounceTime
	lds temp, debounceLeftStatus
	cpi temp, 0
	breq debounceTime
	jmp debounceStatusSkip
debounceTime:
	lds r26, debounceTimer
	lds r27, debounceTimer+1
	adiw r27:r26, 1
	cpi r26, low(800)   ;rounding 800 up ^_^
	ldi temp, high(800)
	cpc temp, r27
	brne debounceStatusSkip				;after debouncy has been set to enable debounce statuses
	;now we want to load the value of temporary counter into the register pair r25/r24

	ldi temp,1
	sts debounceLeftStatus, temp
	sts debounceRightStatus, temp
	clear debounceTimer
	clr r26
	clr r27

debounceStatusSkip:
	sts debounceTimer, r26		;update the value of the temporary counter
	sts debounceTimer+1, r27
	lds r24, tempCounter
	lds r25, tempCounter+1
	adiw r25:r24, 1			;increment the register pair
	cpi r24, low(7812)		;check if the register pair (r25:r24) = 7812
	ldi temp, high(7812)
	cpc r25, temp
	brne NotSecond			;if the register pair are not 7812, a second hasnt passed so we jump to NotSecond which will increase counter by 1
	clear tempCounter
	ldi r24, 0
	sts tempCounter, r24
	sts tempCounter+1, r24
	;now we want to make sure there is a pattern to print if not just end

	lds temp, numberOfBitsInPattern
	cpi temp, 8
	breq waitForNextPatterncheck1
	lds temp, firstPattern
	cpi temp, 0
	breq waitForNextPatterncheck1
	;IF A SECOND HAS PASSED
showPattern:
	lds temp, enableLights
	cpi temp, 0x00			;turn off the lights
	breq flashOff
	;otherwise 
	cpi temp, 0xFF			;turn on the lights
	breq flashOn

waitForNextPatterncheck1:
	lds temp, numberOfBitsInPattern
	cpi temp, 8
	breq setCurrentPattern
	lds temp, numberOfFlashes
	cpi temp, 6
	breq setCurrentPattern
	lds temp, numberOfFlashes
	cpi temp, 0
	breq setCurrentPattern
	jmp timerEpilogue

NotSecond:
	sts TempCounter, r24		;update the value of the temporary counter
	sts TempCounter+1, r25	
	jmp TimerEpilogue

flashOff:
	lds leds, numberOfBitsInPattern
	out portC, leds
	lds temp, numberOFFlashes
	inc temp
	sts numberOfFlashes, temp
	ldi leds, 0x00   ;set led as off pattern
	out PORTC, leds
	;set the enable lights to flash on now
	ldi temp, 0xFF
	sts enableLights, temp
	lds temp, numberOFFlashes
	inc temp
	sts numberOfFlashes, temp
	jmp timerEpilogue

flashOn:
;increment number of flashes
	lds temp, numberOFFlashes
	inc temp
	sts numberOfFlashes, temp
	;load pattern onto screen
	lds temp, patternState
	out portC, temp
	;set the enable lights to flash on now
	ldi temp, 0x00
	sts enableLights, temp
	lds temp, numberOFFlashes
	inc temp
	sts numberOfFlashes, temp
	jmp timerEpilogue

setCurrentPattern:
	ldi temp, 0xff
	sts firstPattern,temp
	lds temp, nextPattern
	sts patternState, temp
	ldi temp, 0
	sts nextPattern, temp

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

PB1_ON_PRESS:
;  PROLOGUE
	in temp, SREG
	push temp
	push YH
	push YL
	push r25
	push r24
	;want to debounce around 10ms 

	lds temp, debounceRightStatus
	cpi temp, 1
	brne pb1epilogue				;the status will be on 10ms after button is pressed
	ldi temp, 0						;now it will be off so after 100ms will be set on again
	sts debounceRightStatus, temp   
	lds temp, numberOfBitsInPattern
	inc temp
	sts numberOfBitsInPattern, temp
	cpi temp, 8
	breq pb1epilogue
	;this button will enter 1 so we load our pattern << to move the bit up (aka multiply by 2) and then add  1 to the end 
	lds temp, nextPattern
	lsl temp
	inc temp
	sts nextPattern, temp
;	out PORTC, temp

pb1Epilogue:
	;epilogue
	pop r24
	pop r25
	pop YL
	pop YH
	pop temp
	;restore our SREG especially xD
	out SREG, temp
	reti	
PB0_ON_PRESS:
;  PROLOGUE
	in temp, SREG
	push temp
	push YH
	push YL
	push r25
	push r24
	;want to debounce around 10ms 
	lds temp, debounceLeftStatus
	cpi temp, 1
	brne pb0epilogue				;the status will be on 10ms after button is pressed
	ldi temp, 0						;now it will be off so after 10ms will be set on again
	sts debounceLeftStatus, temp   
	lds temp, numberOfBitsInPattern
	inc temp
	sts numberOfBitsInPattern, temp
	cpi temp, 8
	breq pb0epilogue
	;this button will enter 1 so we load our pattern << to move the bit up (aka multiply by 2) left shift will cause last bit to be blank
	lds temp, nextPattern
	lsl temp
	sts nextPattern, temp
;debugging my bits
	;lds leds, numberOfBitsInPattern
	;out portC, leds
;	out PORTC, temp

pb0Epilogue:
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
	clear tempCounter
	clear secondCounter
	clear debounceTimer
	clear firstPattern
	ldi temp, 0
	sts firstPattern, temp
	ldi temp, 1
	sts debounceRightStatus, temp 
	sts debounceLeftStatus, temp 
	ldi temp, 0b00000000
	out TCCR0A, temp
	ldi temp, 0b00000010
	out TCCR0B, temp				; prescalining = 8
	ldi temp, 1<<TOIE0				; 128 microseconds
	sts TIMSK0, temp				; T/C0 interrupt enable
	;enable the interrupt for INT0 INT1 based on falling edges of PB1 and PB2

	sei

loop: rjmp loop ; loop 
