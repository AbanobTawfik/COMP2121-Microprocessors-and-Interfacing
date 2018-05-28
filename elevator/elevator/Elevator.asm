.include "m2560def.inc"
.include "macros.asm"
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//																																						 //
//													THESE ARE MACROS USES																				 //
//																																						 //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

.macro do_lcd_data
	ldi r16, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro initalise_LCD
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
	 do_lcd_data ' '
	 do_lcd_data ' '
	 do_lcd_data ' '
	 do_lcd_data ' '
	 do_lcd_data ' '
	 do_lcd_data 'L'
	 do_lcd_data 'i'
	 do_lcd_data 'f'
	 do_lcd_data 't'
	do_lcd_command 0b0011000000    ; address of second line on lcd
	do_lcd_data 'f'
	do_lcd_data 'l'
	do_lcd_data 'o'
	do_lcd_data 'o'
	do_lcd_data 'r'
	do_lcd_data ':'
	do_lcd_data ' '
	do_lcd_data '0'
.endmacro

.macro PRINT_FLOOR
	 do_lcd_command 0b00000001 ; clear display
	 do_lcd_command 0b00000110 ; increment, no display shift
	 do_lcd_command 0b00001110 ; Cursor on, bar, no blink
	 do_lcd_data ' '
	 do_lcd_data ' '
	 do_lcd_data ' '
	 do_lcd_data ' '
	 do_lcd_data ' '
	 do_lcd_data 'L'
	 do_lcd_data 'i'
	 do_lcd_data 'f'
	 do_lcd_data 't'
	 do_lcd_command 0b0011000000    ; address of second line on lcd
	 do_lcd_data 'f'
	 do_lcd_data 'l'
	 do_lcd_data 'o'
 	 do_lcd_data 'o'
	 do_lcd_data 'r'
	 do_lcd_data ':'
	 do_lcd_data ' '
	 mov r16, @0
	 subi r16, -'0'
	 rcall lcd_data
	 rcall lcd_wait
.endmacro

 .macro do_lcd_command
	ldi r16, @0
	rcall lcd_command
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

.macro PRINT_EMERGENCY
	prologue
	do_lcd_command 0b00000001 ; clear display

	do_lcd_command 0b10000000    ; address of first line on lcd
	do_lcd_data 'E'
	do_lcd_data 'm'
	do_lcd_data 'e'
	do_lcd_data 'r'
	do_lcd_data 'g'
	do_lcd_data 'e'
	do_lcd_data 'n'
	do_lcd_data 'c'
	do_lcd_data 'y'
	do_lcd_command 0b0011000000
	do_lcd_data 'c'
	do_lcd_data 'a'
	do_lcd_data 'l'
	do_lcd_data 'l'
	do_lcd_data ':'
	do_lcd_data ' '
	do_lcd_data '0'
	do_lcd_data '0'
	do_lcd_data '0'
	epilogue
.endmacro

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//																																						 //
//													This is the main body of code																		 //
//																																						 //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

.def row = r16						; current row number
.def col = r17						; current column number
.def rmask = r18					; mask for current row during scan
.def cmask = r19					; mask for current column during scan
.def temp1 = r20
.def temp2 = r21
.def topRow = r22
.def bottomRow = r23
.def numberSize = r24
.def temp = r25

.equ PORTLDIR = 0xF0				; PL7-4: output, PL3-0, input 

//for each search we want to start our search at the right most column 0xEF -> 
.equ INITCOLMASK = 0xEF				; 0b1110 1111 scan from the rightmost column,
.equ INITROWMASK = 0x01				; 0b0000 0001 scan from the top row
.equ ROWMASK = 0x0F	

;LED PATTERNS
;door open is 0b11000011 supposed to look like open space for door
.equ DOOR_OPEN = 0xC3
;door closed is 0b11101111 the 0 in middle is the gap for door
.equ DOOR_CLOSED = 0xE7
;door moving up 0b00001111
.equ MOVING_UP = 0xF0
;door moving down 0b11110000
.equ MOVING_DOWN = 0x0F

.dseg
	debounceValue:					; this will check if a key has been pressed
		.byte 1
	lastPressed:
		.byte 1
	secondCounter:
		.byte 1
	tempCounter:			;used to check if a second has passed
		.byte 2
	debounceLeftStatus:
		.byte 1
	debounceRightStatus:
		.byte 1
	debounceTimer:
		.byte 2
	opening:
		.byte 1
	closing:
		.byte 1
	currentFloor:
		.byte 1
	floor_Queue:
		.byte 2
	emergency:
		.byte 1
	down:
		.byte 1

.cseg

.org 0
	jmp RESET
.org INT0addr				; INT0addr is the address of EXT_INT0
	jmp PB0_ON_PRESS
.org INT1addr				; INT1addr is the address of EXT_INT1
	jmp PB1_ON_PRESS		;IRQ0 will be the interrupt handled by connecting PB1 to the INT0 portD aka RDX3

.org OVF0addr
	jmp Timer0OVF			;this will be handler for timer overflow

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
	sts lastPressed, r16
	sts debounceValue, r16
	;initalising output and input for the keypad
	ldi temp1, PORTLDIR					; PA7:4/PA3:0, out/in
	sts DDRL, temp1
	//will make portC output 0xff
	ser temp1							; PORTC is output
	out DDRC, temp1
	;now for the important part is sent INT1 and INT0 to trigger on falling edges for external interupt
	ldi temp, (1 << ISC11) | (1 << ISC01)
	;set the external interrupt control register A to trigger for INT0 and INT1
	;we chose EICRA because it handles for INT0-INT3
	sts EICRA, temp
	;now we want to enable int0 and int1
	in temp, EIMSK
	ori temp, (1 <<INT0) | (1 << INT1)
	out EIMSK, temp
	ldi temp, 1
	sts debounceRightStatus, temp 
	sts debounceLeftStatus, temp 
	ldi temp, 0b00000000
	out TCCR0A, temp
	ldi temp, 0b00000100
	out TCCR0B, temp				; prescalining = 8
	ldi temp, 1<<TOIE0				; 128 microseconds
	sts TIMSK0, temp				; T/C0 interrupt enable
	sei
	//start on floor 0 for the floor (if user presses 0, 1||1 = 1) so starting on 0
	ldi temp, 0
	sts lastPressed, temp
	clear floor_Queue

	ldi temp, 0
	sts currentFloor, temp

	initalise_LCD

	;setup strobe light + motor
		;this is PE2 because from some reason its PE4???????????????????????????
	ldi temp1, 0xff
	;motor + strobe as output
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
	jmp main

;scans through the rows n columns
;if no key is pressed i.e full scan debounce value = 0 means last press = 0, aka no inputs
;if a convert is performed i.e detection will set debounce flag which means key pressed so flag for ispressed is set
;since it jumps to main instead of the held down which resets the debounce flag, it means that the flag is never reset
;this is because it will continously detect input there from the user
;so until a full scan is done where nothing is detected (letting go of the key scanning through all columns false)
;it will not reset flag i.e will not take new input till user lifts finger
;when lifts finger, scans through fully and resets the flag 
;debounce timer of 15ms to make sure multiple inputs arent proccessed and pull up resistors are set with the delay
heldDown:
	ldi temp1, 0
	sts debounceValue, temp1

	
main:
	ldi cmask, INITCOLMASK				; initial column mask
	clr col								; initial column index = 0

colloop:

	cpi col, 4
	breq heldDown							; If all columns are scanned, go back to main.    

	//PORT H -> L CAN ONLY USE STS AND LDS DO NOT SUPPORT OUT AND IN
	sts PORTL, cmask					; Otherwise, scan the next column.
	ldi temp1, 0xFF						; Slowing down the scan operation.

delay:	
										; debouncer for key scan
	dec temp1							; will be set up as pull-up resistors
	brne delay
	call sleep_1ms						; debouncing 50ms
	lds temp1, debouncevalue
	cpi temp1, 0
	breq skip
	ldi temp1, 1
	sts lastPressed, temp1
	jmp skip2

skip:
	ldi temp1, 0
	sts lastPressed, temp1


skip2:
	//we want to load our current cmask (column index) into temp1
	//then we want to and it with the ROWMASK 0x0F to check if any rows in the column are low
	//if we and them together, and get 0xf, that means we have no low rows (so we want to go to next column)
	//since 0x1111 means all row are high but any other result would be low eg 0x0001 -> row 0 or row 3 is low (depends on bit mantisa)
	lds temp1, PINL						; Read PORTL
	andi temp1, ROWMASK					; Get the keypad output value
	cpi temp1, 0xF						; Check if any row is low
	breq nextcol						//if no rows are low i.e all 1111 for the rows we wana ignore dat shit NEXTT
	; If yes, find which row is low
	ldi rmask, INITROWMASK				; Initialize for row check
	clr row  

rowloop:
	cpi row, 4							; if all the rows are scanned we want to go to the next column since no more rows to check in that column
	breq nextcol						; NEXT COLUMN.

	; now we are checking if the key in the column and row index has been pressed
	; temp1 will have our low rows from previous and. if we and the low rows with the rowmask we currently have
	; if result = 0 -> we have a low row key pressed -> convert
	; otherwise we want to keep scanning through the rows
	mov temp2, temp1
	and temp2, rmask					; check un-masked bit (i.e the row column index is LOW -> KEY PRESSED DING DING DING)
	breq convert						; if bit is clear, the key is pressed

	inc row								; else move to the next row (keep scanning)
	lsl rmask							; want to increment the row to scan
	jmp rowloop

nextcol:							; if row scan is over

	lsl cmask							; left shit the column mask
	inc col								; increase column value

	jmp colloop							; go to the next column

convert:
	ldi temp1, 1
	sts debounceValue, temp1

	lds temp1, lastPressed
	cpi temp1, 0
	brne mainjmp


	cpi col, 3								; If the pressed key is in col.3 (column 3 has the letters)
	breq mainjmp							; we have a letter DO NOT HANDLE -> MAIN
	; If the key is not in col.3 and
	cpi row, 3								; If the key is in row3, (row 3 -> symbols)
	breq symboljmp							; we have a symbol or 0

	mov temp1, row							; Otherwise we have a number in 1-9
	lsl temp1								; this will multiply temp1 by 2 
	add temp1, row							; now we have 2temp1 + temp 1 = 3temp1
	add temp1, col							; temp1 = row*3 + col
	subi temp1, -1							; Add the value of  ‘1’ since we aren't starting at 0
	jmp addToQueue

mainjmp:
	jmp main

symboljmp:
	jmp symbols


symbols:
	cpi col, 0								; Check if we have a star
	breq starjmp							; if so do not handle -> MAIN
	cpi col, 1
	breq zerojmp
	jmp main								; otherwise so we do not handle -> MAIN

starjmp:
	jmp star
zerojmp:
	jmp zero
addToQueue:
	ldi XL, 1
	ldi XH, 0 

	CONVERT_FLOOR_INTEGER temp1, XL, XH

	
	lds ZL, floor_Queue
	lds ZH, floor_Queue + 1	


	UPDATE_STATE_ADD ZL,XL,ZH,XH
	sts floor_Queue, ZL
	sts floor_Queue+1,ZH
	;out portC, Z
	jmp main

zero:
	ldi temp1, 0
	jmp addtoQueue

star:
	;resetting the lcd
	;initalising the output in lcd 
	initalise_LCD 
	lds temp, emergency
	cpi temp, 0
	breq emergency_ON
	;emergency off
	ldi temp, 0
	sts emergency, temp
	jmp main
	emergency_ON:
	;want to set emergency flag on
	ldi temp, 0xFF
	sts emergency, temp

	jmp main


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//																																						 //
//													These are Helper Functions																			 //
//																																						 //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


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

sleep_50ms:
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms

	ret

sleep_200ms:
	rcall sleep_50ms
	rcall sleep_50ms
	rcall sleep_50ms
	rcall sleep_50ms
	ret

sleep_1s:
    rcall sleep_200ms
	rcall sleep_200ms
	rcall sleep_200ms
	rcall sleep_200ms
	rcall sleep_200ms
	ret
sleep_2s:
	rcall sleep_1s
	rcall sleep_1s
	ret
sleep_3s:
	rcall sleep_2s
	rcall sleep_1s
	ret
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//																																						 //
//													These are interrupt handlers																		 //
//																																						 //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

DEFAULT:	
	

PB1_ON_PRESS:
;  PROLOGUE
	prologue
	;want to debounce around 10ms 
	lds temp, debounceRightStatus
	cpi temp, 1
	brne pb1epilogue				;the status will be on 10ms after button is pressed
	ldi temp, 0						;now it will be off so after 100ms will be set on again
	sts debounceRightStatus, temp   
	breq pb1epilogue
	;this button will enter 1 so we load our pattern << to move the bit up (aka multiply by 2) and then add  1 to the end 

pb1Epilogue:
	;epilogue
	epilogue
	reti	
PB0_ON_PRESS:
;  PROLOGUE
	prologue
	;want to debounce around 10ms 
	lds temp, debounceLeftStatus
	cpi temp, 1
	brne pb0epilogue				;the status will be on 10ms after button is pressed
	ldi temp, 0						;now it will be off so after 10ms will be set on again
	sts debounceLeftStatus, temp   
	ldi temp, 1
	sts closing, temp
pb0Epilogue:
	;epilogue
	epilogue
	reti	

Timer0OVF:
;storing onto the stack the values we want to preserve and conflict registers
;  PROLOGUE
	prologue
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
	cpi r24, low(7812)		;check if the register pair (r25:r24) = 7812
	ldi temp, high(7812)
	cpc r25, temp
	breq isSecond			;if the register pair are not 7812, a second hasnt passed so we jump to NotSecond which will increase counter by 1
	jmp notSecond
isSecond:
	clear tempCounter
	ldi r24, 0
	sts tempCounter, r24
	sts tempCounter+1, r24
	lds temp1, secondCounter
	inc temp1					;increment the amount of seconds passed
	sts secondCounter, temp1
	lds temp, currentFloor
	sts currentFloor, temp
	PRINT_FLOOR temp
	;now we want our elevator to move if there is stuff in queue, if not we just want to exit so
	lds r24, floor_queue
	lds r25, floor_queue+1		;checking if the queue is empty
	cpi r24, 0
	brne somethinginQueue
	cpi r25, 0
	brne somethinginQueue			;if nothing is in the queue we just want to return!
	jmp nothinginQueue
	somethinginQueue:
	;otherwise we want to check the current queue and see which direction we are travelling in
	;if there is stuff on the queue now we want to know which direction the lift will travel in
	;we want to compare the CURRENT FLOOR to the queue in a way to check if it is moving up or down with the current 
	;the movement of the elevator is simple
	;it will move up all the way till it reaches the top floor
	;then move down all the way till it reaches thw lowest floor, taking floors off the queue on its way
	;to check if we are at the top, we can simply just check if the current floor in bits
	;is higher than the entire queue, since 0b11111110 < 0b00000001
	;now to check if we are at the bottom we simply want to subtract 1 from the queue
	;and AND, if the result is = 0 -> no floors below move up
	;otherwise continue in direction
	lds temp, currentFloor
	;now we want to convert current floor into bit representation
	ldi XL, 1
	ldi XH, 0 
	CONVERT_FLOOR_INTEGER temp, XL, XH
	;queue is in r24:r25 we want a copy of it for our subtraction
	lds temp1, floor_Queue
	lds temp2, floor_Queue + 1
	cp temp1, XL
	cpc temp2, XH
	brne checkk
	rcall open_door
	jmp TimerEpilogue
	checkk:
	lds temp, currentFloor
	;now we want to convert current floor into bit representation
	ldi XL, 1
	ldi XH, 0 
	CONVERT_FLOOR_INTEGER temp, XL, XH
	;queue is in r24:r25 we want a copy of it for our subtraction
	lds temp1, floor_Queue
	lds temp2, floor_Queue + 1
	and temp1, XL
	and temp2, XH
	cpi temp1, 0
	ldi temp, 0
	cpc temp2, temp
	breq checkk2
	rcall open_door
	jmp TimerEpilogue
	checkk2:
	lds temp, currentFloor
	;now we want to convert current floor into bit representation
	ldi XL, 1
	ldi XH, 0 
	CONVERT_FLOOR_INTEGER temp, XL, XH
	;queue is in r24:r25 we want a copy of it for our subtraction
	lds temp1, floor_Queue
	lds temp2, floor_Queue + 1
	cp temp1, XL
	cpc temp2, XH
	brlo moveDown
	;now the second check to change direction
	lds temp, currentFloor
	;now we want to convert current floor into bit representation
	ldi XL, 1
	ldi XH, 0 
	CONVERT_FLOOR_INTEGER temp, XL, XH
	;queue is in r24:r25 we want a copy of it for our subtraction
	lds temp1, floor_Queue
	lds temp2, floor_Queue + 1
	sbiw XH:XL, 1
	and XL, temp1
	and XH, temp2
	cpi XL, 0
	ldi temp, 0
	cpc XH, temp
	;if its = 0 that means direction is up as there are no lower floors
	brne anotherSkip
	jmp moveUp
	anotherSkip:
	jmp continue

moveDown:
	;set direction to be down so down == trye
	ldi temp, 1
	sts down, temp
	jmp continue
moveUp:
	;set direction to be up so down == false
	ldi temp, 0
	sts down, temp
	jmp continue

continue:
	lds temp, down
	cpi temp, 1
	breq continueDown
	;otherwise move up
	jmp continueUp
continueDown:
	ldi temp1, MOVING_DOWN
	out portC, temp1
	;move up the floors checking if a floor is in the queue
	;first check if the CURRENT FLOOR IS ON QUEUE
	;IF IT IS call the open door function
	;return from open if called
	;delay for 2s between floors.
	;increment current floor by 1
	lds temp, currentFloor
	;now we want to convert current floor into bit representation
	ldi XL, 1
	ldi XH, 0 
	CONVERT_FLOOR_INTEGER temp, XL, XH
	;queue is in r24:r25 we want a copy of it for our subtraction
	lds temp1, floor_Queue
	lds temp2, floor_Queue + 1
	and temp1, XL
	and temp2, XH
	cpi temp1, 0
	ldi temp, 0
	cpc temp2, temp
	breq ignoredown
	;in here we will update the queue by removing the current floor
	rcall OPEN_DOOR
	ignoredown:
	;after regardless of return we sleep for 2s
	lds temp, secondCounter
	cpi temp, 2
	breq anotherskipp
	jmp timerEpilogue
	anotherskipp:
	ldi temp, 0
	sts secondCounter, temp
	lds temp, currentFloor
	dec temp
	sts currentFloor, temp
	;do_lcd_data_in_register temp
	jmp timerEpilogue
continueUp:
	ldi temp1, MOVING_UP
	out portC, temp1
;move up the floors checking if a floor is in the queue
	;first check if the CURRENT FLOOR IS ON QUEUE
	;IF IT IS call the open door function
	;return from open if called
	;delay for 2s between floors.
	;increment current floor by 1
	lds temp, currentFloor
	;now we want to convert current floor into bit representation
	ldi XL, 1
	ldi XH, 0 
	CONVERT_FLOOR_INTEGER temp, XL, XH
	;queue is in r24:r25 we want a copy of it for our subtraction
	lds temp1, floor_Queue
	lds temp2, floor_Queue + 1
	and temp1, XL
	and temp2, XH
	cpi temp1, 0
	ldi temp, 0
	cpc temp2, temp
	breq ignoreup
	;in here we will update the queue by removing the current floor
	rcall OPEN_DOOR
	ignoreup:
	;after regardless of return we sleep for 2s
	;after regardless of return we sleep for 2s
	lds temp, secondCounter
	cpi temp, 2
	breq anotherskippr
	jmp timerEpilogue
	anotherskippr:
	ldi temp, 0
	sts secondCounter, temp
	lds temp, currentFloor	
	inc temp
	sts currentFloor, temp
	;do_lcd_data_in_register temp
	jmp timerEpilogue	
NotSecond:
	sts TempCounter, r24		;update the value of the temporary counter
	sts TempCounter+1, r25	
	jmp TimerEpilogue

nothinginQueue:
	ldi temp1, 0
	sts secondCounter, temp1
	jmp timerEpilogue
timerEpilogue:
	epilogue
	reti

OPEN_DOOR:
	prologue
	lds temp, secondCounter
	cpi temp, 3
	brsh skipOpen
	ldi temp1, 0xff
	;initialise voltage to max
	sts OCR3BL, temp1
	sts OCR3BH, temp1
	ldi temp1, DOOR_CLOSED
	out portC, temp1
	jmp TimerEpilogue
	skipOpen:
	ldi temp1, DOOR_OPEN
	out portC, temp1
	;motor spins for 1s then off
	ldi temp1, 0
	;initialise voltage to max
	sts OCR3BL, temp1
	sts OCR3BH, temp1
	lds temp, closing
	cpi temp, 1
	breq startClosing
	lds temp, secondCounter
	cpi temp, 7
	brsh startClosing
	jmp TimerEpilogue
	startClosing:
	ldi temp1, DOOR_CLOSED
	out portC, temp1
	;turn motor on to signal door closing for 1s
	ldi temp1, 0xff
	;initialise voltage to max
	sts OCR3BL, temp1
	sts OCR3BH, temp1
	lds temp, closing
	cpi temp, 1
	breq closecheck
	jmp skipovercheck
	closecheck:
	lds temp, secondCounter
	cpi temp, 4
	brlo closed
	skipovercheck:
	lds temp, secondCounter
	cpi temp, 9
	brsh closed
	jmp TimerEpilogue
	closed:
	;turn motor off and return
	ldi temp1, 0
	;initialise voltage to max
	sts OCR3BL, temp1
	sts OCR3BH, temp1
	sts secondCounter, temp1
	sts closing, temp1

	lds temp, currentFloor
	;now we want to convert current floor into bit representation
	ldi XL, 1
	ldi XH, 0 
	CONVERT_FLOOR_INTEGER temp, XL, XH
	lds ZL, floor_Queue
	lds ZH, floor_Queue + 1	
	eor ZL,XL 
	eor ZH,XH
	sts floor_Queue, ZL
	sts floor_Queue+1,ZH
	epilogue
	ret
