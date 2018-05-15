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

;flag for motor on
.equ MOT_ON = 1
;flag for motor off
.equ MOT_OFF = 0
;these are to signify the maximum and minimum floor
.equ TOP_FLOOR = 9
.equ BOTTOM_FLOOR = 0
;LED PATTERNS
;door open is 0b11000011 supposed to look like open space for door
.equ DOOR_OPEN = 0xC3
;door closed is 0b11101111 the 0 in middle is the gap for door
.equ DOOR_CLOSED = 0xF7
;door moving up 0b00001111
.equ MOVING_UP = 0x0F
;door moving down 0b11110000
.equ MOVING_DOWN = 0xF0

.dseg
	debounceValue:					; this will check if a key has been pressed
		.byte 1
	lastPressed:
		.byte 1
	patternState:
		.byte 1				;single 8 byte pattern to show
	secondCounter:			;3 flashes 1s each so when this second counter is 3 we reset, and overwrite pattern with new 1
		.byte 2
	tempCounter:			;used to check if a second has passed
		.byte 2
	debounceLeftStatus:
		.byte 1
	debounceRightStatus:
		.byte 1
	debounceTimer:
		.byte 2

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
	out PORTC, temp1
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
	ldi temp, 0b00000010
	out TCCR0B, temp				; prescalining = 8
	ldi temp, 1<<TOIE0				; 128 microseconds
	sts TIMSK0, temp				; T/C0 interrupt enable
	sei


	initalise_LCD
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

delay:									; debouncer for key scan
	dec temp1							; will be set up as pull-up resistors
	brne delay
	call sleep_15ms						; debouncing 50ms

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

	out PORTC, temp1

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
	add bottomRow, temp1					; append the number to the end

	jmp addToQueue

mainjmp:
	jmp main

symboljmp:
	jmp symbols


symbols:
	cpi col, 0							; Check if we have a star
	breq starjmp							; if so do not handle -> MAIN
	jmp main							; otherwise so we do not handle -> MAIN

starjmp:
	jmp star

addToQueue:

	out portC, bottomRow

	jmp main
star:
	;resetting the lcd
	;initalising the output in lcd 
	initalise_LCD


	clr topRow
	clr bottomRow
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


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//																																						 //
//													These are interrupt handlers																		 //
//																																						 //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

PB1_ON_PRESS:
;  PROLOGUE
	prologue
	;want to debounce around 10ms 
	lds temp, debounceRightStatus
	cpi temp, 1
	brne pb1epilogue				;the status will be on 10ms after button is pressed
	ldi temp, 0						;now it will be off so after 100ms will be set on again
	sts debounceRightStatus, temp   
	;out portC, temp
	breq pb1epilogue
	;this button will enter 1 so we load our pattern << to move the bit up (aka multiply by 2) and then add  1 to the end 

;	out PORTC, temp

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



pb0Epilogue:
	;epilogue
	epilogue
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
	cpi r24, low(7812)		;check if the register pair (r25:r24) = 7812
	ldi temp, high(7812)
	cpc r25, temp
	brne NotSecond			;if the register pair are not 7812, a second hasnt passed so we jump to NotSecond which will increase counter by 1
	clear tempCounter
	ldi r24, 0
	sts tempCounter, r24
	sts tempCounter+1, r24
	



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