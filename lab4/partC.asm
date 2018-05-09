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

.def row = r16						; current row number
.def col = r17						; current column number
.def rmask = r18					; mask for current row during scan
.def cmask = r19					; mask for current column during scan
.def temp1 = r20
.def temp2 = r21
.def topRow = r22
.def bottomRow = r23
.def numberSize = r24
.def flag = r25

.equ PORTLDIR = 0xF0				; PL7-4: output, PL3-0, input 

//for each search we want to start our search at the right most column 0xEF -> 
.equ INITCOLMASK = 0xEF				; 0b1110 1111 scan from the rightmost column,
.equ INITROWMASK = 0x01				; 0b0000 0001 scan from the top row
.equ ROWMASK = 0x0F	

.dseg
	debounceValue:					; this will check if a key has been pressed
		.byte 1
.cseg

.org 0
	jmp RESET


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

	;initalising output and input for the keypad
	ldi temp1, PORTLDIR					; PA7:4/PA3:0, out/in
	sts DDRL, temp1
	//will make portC output 0xff
	ser temp1							; PORTC is output
	out DDRC, temp1
	out PORTC, temp1
	
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
	do_lcd_data '0'
	clr topRow
	clr bottomRow

main:
	lds YL, debounceValue
	cpi YL, 0
	breq initscan
	call sleep_50ms
	call sleep_50ms
	call sleep_50ms
	ldi YL, 0
	sts debounceValue, YL
initscan:
	ldi cmask, INITCOLMASK				; initial column mask
	clr col								; initial column index = 0

colloop:
	cpi col, 4
	breq main							; If all columns are scanned, go back to main.      
	//PORT H -> L CAN ONLY USE STS AND LDS DO NOT SUPPORT OUT AND IN
	sts PORTL, cmask					; Otherwise, scan the next column.
	ldi temp1, 0xFF						; Slowing down the scan operation.

delay:									; debouncer for key scan
	dec temp1							; will be set up as pull-up resistors
	brne delay
	call sleep_50ms						; debouncing 10ms



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


	cpi col, 3							; If the pressed key is in col.3 (column 3 has the letters)
	breq letters							; we have a letter DO NOT HANDLE -> MAIN
	; If the key is not in col.3 and
	cpi row, 3							; If the key is in row3, (row 3 -> symbols)
	breq symbols						; we have a symbol or 0

	mov temp1, row						; Otherwise we have a number in 1-9
	lsl temp1							; this will multiply temp1 by 2 
	add temp1, row						; now we have 2temp1 + temp 1 = 3temp1
	add temp1, col						; temp1 = row*3 + col

	subi temp1, -1						; Add the value of  1 since we aren't starting at 0
;to make sure the key press is unique i will load it in and compare with whats stored, if already stored return this way the user can just hold down


	ldi XH, 10	
	mul bottomRow, XH						; to append the number to the end (base 10 digits) we multiply by 10
	mov bottomRow, r0
	add bottomRow, temp1					; append the number to the end
	jmp display

symbols:
	cpi col, 0							; Check if we have a star
	breq star							; if so do not handle -> MAIN
	cpi col, 1							; or if we have zero
	breq multiply10						; multiply by 10
	jmp main							; otherwise so we do not handle -> MAIN

multiply10:
	ldi XH, 10	
	mul bottomRow, XH						; to append the number to the end (base 10 digits) we multiply by 10
	mov bottomRow, r0
	jmp display

letters:
	cpi row, 0							;row 0 in col 3 -> A -> ADDITION
	breq addition
	cpi row, 1
	breq subtraction
	cpi row, 2
	breq multiplication
	jmp main

addition:
	
;add to the accumulated value the value on the bottom entered 
	add topRow, bottomRow
;reset value on bottom
	clr bottomRow
	do_lcd_command 0b00000001 ; clear display
;now we want to update display
;return to main
	jmp display

subtraction:
;add to the accumulated value the value on the bottom entered 
	sub topRow, bottomRow 
;reset value on bottom
	clr bottomRow
	do_lcd_command 0b00000001 ; clear display
;now we want to update display
;return to main
	jmp display

display:
	
	do_lcd_command 0b10000000    ; address of first line on lcd
	do_lcd_8bit topRow

	do_lcd_command 0b0011000000    ; address of second line on lcd
	;now we want to print our bottom row register in the bottom row
	do_lcd_8bit bottomRow

	jmp main

multiplication:
;add to the accumulated value the value on the bottom entered 
	mul topRow, bottomRow 
;reset value on bottom
	mov topRow, r0
	clr bottomRow
	do_lcd_command 0b00000001 ; clear display
;now we want to update display
;return to main
	jmp display	

star:
	;resetting the lcd
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
	do_lcd_data '0'
	clr topRow
	clr bottomRow
	jmp main



	
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
	ldi XL, 0
	ldi numberSize, 0
	Hundreds_Counter:
		cpi r16, 100
		brsh add_hundreds
		cpi flag, 0
		brne save_counter_hundreds
	
	Tens_Counter:
		cpi r16, 10
		brsh add_tens
		;say we have the number 100, since 100 - 100 = 0, we have no numebr to compare with but we still need to load in 0
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
	inc XL
	subi r16, 100
	jmp Hundreds_Counter

save_counter_hundreds:
;we want to store the hundreds digit counter 	
	push XL
	inc numberSize
	clr flag
	clr XL
	jmp Tens_Counter
	;we want to push onto 
	
add_tens:
;set flag as true there are hundreds digits
	ldi flag, 0xff
	;increment the digits counter for hundreds
	inc XL
	subi r16, 10
	jmp tens_counter

save_counter_tens:
;we want to store the hundreds digit counter 	
	push XL
	inc numberSize
	clr flag
	clr XL
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
sleep_50ms:
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms


	ret
