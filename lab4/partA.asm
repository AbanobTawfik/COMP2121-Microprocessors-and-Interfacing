/*
Part A – Keypad (3 Marks)
Write a program to detect keypad presses and display them on the LEDs. Buttons 0-9 should display
their numeric value in binary, with the lsb at the bottom. The other buttons do not need to be
handled.
The keypad should be connected to PORTL, with none of the wires crossed over (same as lab 3). The
low 4 bits will be connected to the rows, and the high 4 bits will be used to read the column outputs.
You will need to activate the pull-up resistors on the input pins to reliably detect key presses.
*/

.include "m2560def.inc"
.def row = r16						; current row number
.def col = r17						; current column number
.def rmask = r18					; mask for current row during scan
.def cmask = r19					; mask for current column during scan
.def temp1 = r20
.def temp2 = r21

//we are setting this up so the higher bits (columns) are input
//and the lower 4 bits which are row, are output
//we press key will check which column has the low row
.equ PORTLDIR = 0xF0				; PL7-4: output, PL3-0, input 

//for each search we want to start our search at the right most column 0xEF -> 
.equ INITCOLMASK = 0xEF				; 0b1110 1111 scan from the rightmost column,
.equ INITROWMASK = 0x01				; 0b0000 0001 scan from the top row
.equ ROWMASK = 0x0F					; for obtaining input from Port L


RESET:
ldi temp1, low(RAMEND)				; initialize the stack
out SPL, temp1
ldi temp1, high(RAMEND)
out SPH, temp1

//since portL cannot support 16 bit instruction out and in we use sts and lds instead
ldi temp1, PORTLDIR					; PA7:4/PA3:0, out/in
sts DDRL, temp1
//will make portC output 0xff
ser temp1							; PORTC is output
out DDRC, temp1
out PORTC, temp1

main:
ldi cmask, INITCOLMASK				; initial column mask
clr col								; initial column index = 0

colloop:
cpi col, 4
breq main							; If all columns are scanned, go back to main.      
//PORT H -> L CAN ONLY USE STS AND LDS DO NOT SUPPORT OUT AND IN
sts PORTL, cmask					; Otherwise, scan the next column.
ldi temp1, 0xFF						; Slowing down the scan operation.

delay:								; debouncer for key scan
dec temp1							; will be set up as pull-up resistors
brne delay

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


/*
We only want to consider the following
1-3 row 0, col 0-2 1->[0,0] 2->[0,1] 3->[0,2]
4-6 row 1, col 0-2 4->[1,0] 5->[1,1] 6->[1,2]
7-9 row 2, col 0-2 7->[2,0] 8->[2,1] 9->[2,2]
0   row 3, col 1   0->[3,0]

key value = 3*(row number+1) + (col number + 1)  since indexing starts at 0

*/

convert:
cpi col, 3							; If the pressed key is in col.3 (column 3 has the letters)
breq main							; we have a letter DO NOT HANDLE -> MAIN
; If the key is not in col.3 and
cpi row, 3							; If the key is in row3, (row 3 -> symbols)
breq symbols						; we have a symbol or 0

mov temp1, row						; Otherwise we have a number in 1-9
lsl temp1							; this will multiply temp1 by 2 
add temp1, row						; now we have 2temp1 + temp 1 = 3temp1
add temp1, col						; temp1 = row*3 + col
subi temp1, -'1'					; Add the value of character ‘1’ since we aren't starting at 0
jmp convert_end

symbols:
cpi col, 0							; Check if we have a star
breq main							; if so do not handle -> MAIN
cpi col, 1							; or if we have zero
breq zero							; we print zeroes!
jmp main							; otherwise so we do not handle -> MAIN


zero:
ldi temp1, '0'						; Set to zero

convert_end:
out PORTC, temp1					; Write value to PORTC
jmp main							; Restart main loop

/*
sec ; else shift the column mask:
; We must set the carry bit
rol mask ; and then rotate left by a bit,
; shifting the carry into
; bit zero. We need this to make
; sure all the rows have
; pull-up resistors
*/
