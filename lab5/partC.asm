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
	clr temp
	st Y+, temp		;we clear the two bytes located where the label @a0 is by loading in a clear byte
	st Y, temp

.endmacro

.macro do_lcd_command
	ldi r16, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

.macro do_lcd_data
	ldi r16, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro do_lcd_data_in_register
	mov r16, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro do_lcd_8bit
	mov r16, @0
	rcall lcd_8bit
	rcall lcd_wait
.endmacro

.def temp = r16
.def temp1 = r20
.def temp2 = r21
.def topRow = r22
.def rotations = r17
.def numberSize = r18
.def flag = r19
.def init = r23

.dseg
	debounceLeftStatus:
		.byte 1
	debounceRightStatus:
		.byte 1
	debounceTimer:
		.byte 2
	secondCounter:			;3 flashes 1s each so when this second counter is 3 we reset, and overwrite pattern with new 1
		.byte 2
	tempCounter:			;used to check if a second has passed
		.byte 2

.cseg

.org 0
	jmp RESET
.org INT0addr ; INT0addr is the address of EXT_INT0
	jmp PB0_ON_PRESS
.org INT1addr ; INT1addr is the address of EXT_INT1
	jmp PB1_ON_PRESS	;IRQ0 will be the interrupt handled by connecting PB1 to the INT0 portD aka RDX3
.org INT2ADDR
	jmp INTERRUPT2
.org OVF0addr
	jmp Timer0OVF		;this will be handler for timer overflow


RESET:
	ldi r16, low(RAMEND)
	out SPL, r16
	ldi r16, high(RAMEND)
	out SPH, r16

	ser r16
	out DDRF, r16
	out DDRA, r16
	clr r16
	out PORTF, r16
	out PORTA, r16
	out DDRC, r16
	;this is PE2 because from some reason its PE4???????????????????????????
	ldi temp1, 0b00010000
	;we only want to output the red LED ontop
	out DDRE, temp1
	;show the red LED
	ldi temp1, 0xFF
	out portE, temp1
	out DDRC, temp1
	ldi temp1, 0
	;initialise voltage to max
	sts OCR3BL, temp1
	sts OCR3BH, temp1
	ldi temp1, (1 << CS30) 		; set the Timer3 to Phase Correct PWM mode. 
	sts TCCR3B, temp1
	ldi temp1, (1<< WGM30)|(1<<COM3B1)
	sts TCCR3A, temp1
	

	ldi temp1, 0b00000000
	out TCCR0A, temp1
	ldi temp1, 0b00000010
	out TCCR0B, temp1				; prescalining = 8
	ldi temp1, 1<<TOIE0				; 128 microseconds
	sts TIMSK0, temp1				; T/C0 interrupt enable
	;now for the important part is sent INT1 and INT0 to trigger on falling edges for external interupt
	ldi temp, (1 << ISC11) | (1 << ISC01) | (2 <<ISC20)
	;set the external interrupt control register A to trigger for INT0 and INT1
	;we chose EICRA because it handles for INT0-INT3
	sts EICRA, temp
	;now we want to enable int0 and int1
	in temp, EIMSK
	ori temp, (1 <<INT0) | (1 << INT1) | (1<<INT2)
	out EIMSK, temp
	;initalising the output in lcd 
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_5ms
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_1ms
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00001000 ; display off?
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001110 ; Cursor on, bar, no blink
	;initally load 0 on reset in top left corner
	do_lcd_data 't'
	do_lcd_data 'a'
	do_lcd_data 'r'
	do_lcd_data 'g'
	do_lcd_data 'e'
	do_lcd_data 't'
	do_lcd_data ':'
	do_lcd_data '0'
	do_lcd_command 0b0011000000    ; address of second line on lcd
	do_lcd_data 'c'
	do_lcd_data 'u'
	do_lcd_data 'r'
	do_lcd_data 'r'
	do_lcd_data 'e'
	do_lcd_data 'n'
	do_lcd_data 't'
	do_lcd_data ':'
	do_lcd_data '0'

	clr topRow
	clr rotations
	sei
loop: jmp loop

;scans through the rows n columns
;if no key is pressed i.e full scan debounce value = 0 means last press = 0, aka no inputs
;if a convert is performed i.e detection will set debounce flag which means key pressed so flag for ispressed is set
;since it jumps to main instead of the held down which resets the debounce flag, it means that the flag is never reset
;this is because it will continously detect input there from the user
;so until a full scan is done where nothing is detected (letting go of the key scanning through all columns false)
;it will not reset flag i.e will not take new input till user lifts finger
;when lifts finger, scans through fully and resets the flag 
;debounce timer of 15ms to make sure multiple inputs arent proccessed and pull up resistors are set with the delay

display:
	
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001110 ; Cursor on, bar, no blink

	do_lcd_data 't'
	do_lcd_data 'a'
	do_lcd_data 'r'
	do_lcd_data 'g'
	do_lcd_data 'e'
	do_lcd_data 't'
	do_lcd_data ':'
	do_lcd_8bit topRow
	do_lcd_command 0b0011000000    ; address of second line on lcd
	do_lcd_data 'c'
	do_lcd_data 'u'
	do_lcd_data 'r'
	do_lcd_data 'r'
	do_lcd_data 'e'
	do_lcd_data 'n'
	do_lcd_data 't'
	do_lcd_data ':'
	do_lcd_8bit rotations
	clr rotations
	ret


	
/*
We only want to consider the following
1-3 row 0, col 0-2 1->[0,0] 2->[0,1] 3->[0,2]
4-6 row 1, col 0-2 4->[1,0] 5->[1,1] 6->[1,2]
7-9 row 2, col 0-2 7->[2,0] 8->[2,1] 9->[2,2]
0   row 3, col 1   0->[3,0]

key value = 3*(row number+1) + (col number + 1)  since indexing starts at 0

*/

.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

.macro lcd_set
	sbi PORTA, @0
.endmacro
.macro lcd_clr
	cbi PORTA, @0
.endmacro


; 8bit digit stored in r16
; since 8 bit max is 255, maximum digit 100's, 10's ,1's -> NO case of 1000's
; want to first start with 100's, subtract 100 compare with 0, increment the hundreds counter each time > 0	
; once < 0, we want to subtract 10's compare with 0, increment the tens counter each time > 0
; once < 0, we want to subtract 1's compare with 0, increment the ones counter each time > 0
; we want to convert those counters into ascii, then lcd_data command easy
lcd_8bit:
;flag for checking if integer type is there
	ldi flag, 0
	ldi temp1, 0
	ldi numberSize, 0
	Hundreds_Counter:
		cpi r16, 100
		brsh add_hundreds
		cpi flag, 0
		brne save_counter_hundreds
	
	Tens_Counter:
		cpi r16, 10
		brsh add_tens
		;say we have the number 100, since 100 - 100 = 0, we have no numebr to compare with but we still need to load in 0 so we dont just print 1
		cpi numberSize, 1
		breq save_counter_tens
		cpi flag, 0
		brne save_counter_tens

   ;since the ones are always no matter what shown for all numbers, we can just store the remainder of our check hundreds and check tens
	Ones_Counter:
		push r16			; the remainder from our tens and hundreds
		inc numberSize		; increase number size by 1
		;now we want to print based on how many numbers there are
		cpi numberSize, 3
		breq print3Digits
		cpi numberSize, 2
		breq print2Digits
		cpi numberSize, 1
		breq printDigit

add_hundreds:
;set flag as true there are hundreds digits
	ldi flag, 0xff
	;increment the digits counter for hundreds
	inc temp1
	subi r16, 100
	jmp Hundreds_Counter

save_counter_hundreds:
;we want to store the hundreds digit counter 	
	push temp1
	inc numberSize
	clr flag
	clr temp1
	jmp Tens_Counter
	;we want to push onto 
	
add_tens:
;set flag as true there are hundreds digits
	ldi flag, 0xff
	;increment the digits counter for hundreds
	inc temp1
	subi r16, 10
	jmp tens_counter

save_counter_tens:
;we want to store the hundreds digit counter 	
	push temp1
	inc numberSize
	clr flag
	clr temp1
	jmp ones_Counter
	;we want to push onto 

print3Digits:
	pop flag
	pop temp1
	pop temp2

	;converting the integers into ascii for display (no addi) feelsbadman 
	subi temp2, -'0' 
	subi temp1, -'0' 
	subi flag, -'0' 
	do_lcd_data_in_register temp2
	do_lcd_data_in_register temp1
	do_lcd_data_in_register flag
	ret

print2Digits:
	pop temp1
	pop temp2

	subi temp2, -'0' 
	subi temp1, -'0' 

	do_lcd_data_in_register temp2
	do_lcd_data_in_register temp1
	ret

printDigit:
	pop temp1
	subi temp1, -'0' 

	do_lcd_data_in_register temp1
	ret
	
;
; Send a command to the LCD (r16)
;
lcd_command:
	out PORTF, r16
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	ret

lcd_data:
	out PORTF, r16
	lcd_set LCD_RS
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	lcd_clr LCD_RS
	ret

lcd_wait:
	push r16
	clr r16
	out DDRF, r16
	out PORTF, r16
	lcd_set LCD_RW
lcd_wait_loop:
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	in r16, PINF
	lcd_clr LCD_E
	sbrc r16, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser r16
	out DDRF, r16
	pop r16
	ret

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

sleep_5ms:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ret
sleep_15ms:
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	ret


INTERRUPT2:
	in temp1, SREG
	push temp1
	inc rotations
	pop temp1
	out SREG, temp1
	reti

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
	cpi r26, low(1800)   ;rounding 800 up ^_^
	ldi temp, high(1800)
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
	cpi r24, low(2000)		;check if the register pair (r25:r24) = 7812
	ldi temp, high(2000)
	cpc r25, temp
	brne NotSecond			;if the register pair are not 7812, a second hasnt passed so we jump to NotSecond which will increase counter by 1
	out portC, rotations
	clear tempCounter
	ldi r24, 0
	sts tempCounter, r24
	sts tempCounter+1, r24
	rcall display	
	jmp TimerEpilogue

NotSecond:
	sts TempCounter, r24		;update the value of the temporary counter
	sts TempCounter+1, r25	
	jmp TimerEpilogue


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
	cpi topRow, 100
	brsh pb0epilogue
	subi topRow, -20
	sts OCR3BL, topRow
	


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
	ldi temp, 0
	sts debounceLeftStatus, temp
	cpi topRow, 19
	brlo pb0epilogue
    subi topRow, 20
	sts OCR3BL, topRow
	
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
